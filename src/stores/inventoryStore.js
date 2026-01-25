import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from 'src/boot/supabase'

export const useInventoryStore = defineStore('inventory', () => {
  // ============================================
  // STATE - Extended SAP B1 Features
  // ============================================

  // Bin Locations
  const binLocations = ref([])
  const binStock = ref([])

  // Cycle Counting
  const cycleCounts = ref([])
  const currentCycleCount = ref(null)

  // Pick & Pack
  const pickLists = ref([])
  const currentPickList = ref(null)

  // Price Lists
  const priceLists = ref([])
  const priceListItems = ref([])

  // Sales & Delivery
  const salesOrders = ref([])
  const deliveryDocuments = ref([])

  // Stock Audit Trail (OINM)
  const stockAuditTrail = ref([])

  // Journal Entries
  const journalEntries = ref([])

  // UI State
  const loading = ref(false)
  const error = ref(null)

  // ============================================
  // GETTERS
  // ============================================

  const activeBinLocations = computed(() => binLocations.value.filter((b) => b.is_active))

  const activePriceLists = computed(() => priceLists.value.filter((p) => p.is_active))

  const defaultPriceList = computed(
    () => priceLists.value.find((p) => p.is_default) || priceLists.value[0],
  )

  const pendingSalesOrders = computed(() =>
    salesOrders.value.filter((so) => so.status === 'approved'),
  )

  const openPickLists = computed(() =>
    pickLists.value.filter((pl) => pl.status === 'open' || pl.status === 'in_progress'),
  )

  const pendingCycleCounts = computed(() =>
    cycleCounts.value.filter(
      (cc) => cc.status === 'in_progress' || cc.status === 'pending_approval',
    ),
  )

  // ============================================
  // BIN LOCATIONS
  // ============================================

  async function fetchBinLocations(warehouseId = null) {
    try {
      loading.value = true
      let query = supabase
        .from('bin_locations')
        .select('*, warehouse:warehouses(id, name, code)')
        .order('bin_code')

      if (warehouseId) {
        query = query.eq('warehouse_id', warehouseId)
      }

      const { data, error: fetchError } = await query
      if (fetchError) throw fetchError
      binLocations.value = data
      return { success: true, data }
    } catch (err) {
      console.error('Error fetching bin locations:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function createBinLocation(binData) {
    try {
      loading.value = true
      const { data, error: insertError } = await supabase
        .from('bin_locations')
        .insert(binData)
        .select('*, warehouse:warehouses(id, name, code)')
        .single()

      if (insertError) throw insertError
      binLocations.value.push(data)
      return { success: true, data }
    } catch (err) {
      console.error('Error creating bin location:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function updateBinLocation(id, updates) {
    try {
      loading.value = true
      const { data, error: updateError } = await supabase
        .from('bin_locations')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select('*, warehouse:warehouses(id, name, code)')
        .single()

      if (updateError) throw updateError
      const index = binLocations.value.findIndex((b) => b.id === id)
      if (index !== -1) binLocations.value[index] = data
      return { success: true, data }
    } catch (err) {
      console.error('Error updating bin location:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // ============================================
  // CYCLE COUNTING
  // ============================================

  async function fetchCycleCounts() {
    try {
      loading.value = true
      const { data, error: fetchError } = await supabase
        .from('cycle_counts')
        .select(
          `
          *,
          warehouse:warehouses(id, name, code),
          counted_by_user:profiles!cycle_counts_counted_by_fkey(full_name),
          approved_by_user:profiles!cycle_counts_approved_by_fkey(full_name),
          cycle_count_lines(
            *,
            item:items(id, item_code, item_name),
            bin_location:bin_locations(id, bin_code)
          )
        `,
        )
        .order('created_at', { ascending: false })

      if (fetchError) throw fetchError
      cycleCounts.value = data
      return { success: true, data }
    } catch (err) {
      console.error('Error fetching cycle counts:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function createCycleCount(ccData, lines) {
    try {
      loading.value = true

      // Generate doc number
      const { data: docNum } = await supabase.rpc('generate_doc_number', { p_doc_type: 'CC' })

      const { data: cc, error: ccError } = await supabase
        .from('cycle_counts')
        .insert({ ...ccData, doc_number: docNum })
        .select()
        .single()

      if (ccError) throw ccError

      // Insert lines with system quantities
      const ccLines = lines.map((line, index) => ({
        cycle_count_id: cc.id,
        line_num: index + 1,
        item_id: line.item_id,
        bin_location_id: line.bin_location_id,
        batch_number: line.batch_number,
        system_quantity: line.system_quantity,
        unit_cost: line.unit_cost,
        count_status: 'pending',
      }))

      const { error: linesError } = await supabase.from('cycle_count_lines').insert(ccLines)
      if (linesError) throw linesError

      await fetchCycleCounts()
      return { success: true, data: cc }
    } catch (err) {
      console.error('Error creating cycle count:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function updateCycleCountLine(lineId, countedQty, remarks = null) {
    try {
      const { data: line, error: fetchError } = await supabase
        .from('cycle_count_lines')
        .select('system_quantity, unit_cost')
        .eq('id', lineId)
        .single()

      if (fetchError) throw fetchError

      const variance = countedQty - line.system_quantity
      const varianceValue = variance * (line.unit_cost || 0)

      const { error: updateError } = await supabase
        .from('cycle_count_lines')
        .update({
          counted_quantity: countedQty,
          variance_quantity: variance,
          variance_value: varianceValue,
          count_status: 'counted',
          remarks,
        })
        .eq('id', lineId)

      if (updateError) throw updateError
      return { success: true }
    } catch (err) {
      console.error('Error updating cycle count line:', err)
      return { success: false, error: err.message }
    }
  }

  async function completeCycleCount(ccId, approvedBy) {
    try {
      loading.value = true
      const { data, error: updateError } = await supabase
        .from('cycle_counts')
        .update({
          status: 'completed',
          approved_by: approvedBy,
          approved_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', ccId)
        .select()
        .single()

      if (updateError) throw updateError
      await fetchCycleCounts()
      return { success: true, data }
    } catch (err) {
      console.error('Error completing cycle count:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // ============================================
  // PICK & PACK
  // ============================================

  async function fetchPickLists() {
    try {
      loading.value = true
      const { data, error: fetchError } = await supabase
        .from('pick_lists')
        .select(
          `
          *,
          warehouse:warehouses(id, name, code),
          assigned_user:profiles!pick_lists_assigned_to_fkey(full_name),
          pick_list_lines(
            *,
            item:items(id, item_code, item_name),
            from_bin:bin_locations!pick_list_lines_from_bin_location_id_fkey(id, bin_code),
            uom:units_of_measure(id, code, name)
          )
        `,
        )
        .order('created_at', { ascending: false })

      if (fetchError) throw fetchError
      pickLists.value = data
      return { success: true, data }
    } catch (err) {
      console.error('Error fetching pick lists:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function createPickList(plData, lines) {
    try {
      loading.value = true

      const { data: docNum } = await supabase.rpc('generate_doc_number', { p_doc_type: 'PL' })

      const { data: pl, error: plError } = await supabase
        .from('pick_lists')
        .insert({
          ...plData,
          doc_number: docNum,
          total_items: lines.length,
        })
        .select()
        .single()

      if (plError) throw plError

      const plLines = lines.map((line, index) => ({
        pick_list_id: pl.id,
        line_num: index + 1,
        item_id: line.item_id,
        source_doc_type: line.source_doc_type,
        source_doc_id: line.source_doc_id,
        source_line_id: line.source_line_id,
        from_bin_location_id: line.from_bin_location_id,
        required_quantity: line.required_quantity,
        uom_id: line.uom_id,
        pick_status: 'pending',
      }))

      const { error: linesError } = await supabase.from('pick_list_lines').insert(plLines)
      if (linesError) throw linesError

      await fetchPickLists()
      return { success: true, data: pl }
    } catch (err) {
      console.error('Error creating pick list:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function updatePickListLine(lineId, pickedQty) {
    try {
      const { error: updateError } = await supabase
        .from('pick_list_lines')
        .update({
          picked_quantity: pickedQty,
          pick_status: 'picked',
          picked_at: new Date().toISOString(),
        })
        .eq('id', lineId)

      if (updateError) throw updateError
      return { success: true }
    } catch (err) {
      console.error('Error updating pick list line:', err)
      return { success: false, error: err.message }
    }
  }

  // ============================================
  // PRICE LISTS
  // ============================================

  async function fetchPriceLists() {
    try {
      loading.value = true
      const { data, error: fetchError } = await supabase
        .from('price_lists')
        .select('*')
        .order('price_list_name')

      if (fetchError) throw fetchError
      priceLists.value = data
      return { success: true, data }
    } catch (err) {
      console.error('Error fetching price lists:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function createPriceList(plData) {
    try {
      loading.value = true
      const { data, error: insertError } = await supabase
        .from('price_lists')
        .insert(plData)
        .select()
        .single()

      if (insertError) throw insertError
      priceLists.value.push(data)
      return { success: true, data }
    } catch (err) {
      console.error('Error creating price list:', err)
      if (err.code === '23505' || err.status === 409) {
        return { success: false, error: 'Price List with this code or name already exists.' }
      }
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function fetchPriceListItems(priceListId) {
    try {
      const { data, error: fetchError } = await supabase
        .from('price_list_items')
        .select(
          `
          *,
          item:items(id, item_code, item_name),
          uom:units_of_measure(id, code, name)
        `,
        )
        .eq('price_list_id', priceListId)
        .order('created_at')

      if (fetchError) throw fetchError
      priceListItems.value = data
      return { success: true, data }
    } catch (err) {
      console.error('Error fetching price list items:', err)
      return { success: false, error: err.message }
    }
  }

  async function addPriceListItem(itemData) {
    try {
      const { data, error: insertError } = await supabase
        .from('price_list_items')
        .insert(itemData)
        .select(`*, item:items(id, item_code, item_name)`)
        .single()

      if (insertError) throw insertError
      priceListItems.value.push(data)
      return { success: true, data }
    } catch (err) {
      console.error('Error adding price list item:', err)
      return { success: false, error: err.message }
    }
  }

  async function getItemPrice(itemId, priceListId, quantity = 1) {
    try {
      const { data, error: fetchError } = await supabase
        .from('price_list_items')
        .select('price, discount_percent')
        .eq('item_id', itemId)
        .eq('price_list_id', priceListId)
        .eq('is_active', true)
        .lte('min_quantity', quantity)
        .or(`max_quantity.is.null,max_quantity.gte.${quantity}`)
        .order('min_quantity', { ascending: false })
        .limit(1)
        .single()

      if (fetchError && fetchError.code !== 'PGRST116') throw fetchError
      return data || null
    } catch (err) {
      console.error('Error getting item price:', err)
      return null
    }
  }

  // ============================================
  // SALES ORDERS
  // ============================================

  async function fetchSalesOrders() {
    try {
      loading.value = true
      const { data, error: fetchError } = await supabase
        .from('sales_orders')
        .select(
          `
          *,
          warehouse:warehouses(id, name, code),
          price_list:price_lists(id, price_list_name),
          created_by_user:profiles!sales_orders_created_by_fkey(full_name),
          sales_order_lines(
            *,
            item:items(id, item_code, item_name),
            uom:units_of_measure(id, code, name)
          )
        `,
        )
        .order('created_at', { ascending: false })

      if (fetchError) throw fetchError
      salesOrders.value = data
      return { success: true, data }
    } catch (err) {
      console.error('Error fetching sales orders:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function createSalesOrder(soData, lines) {
    try {
      loading.value = true

      const { data: docNum } = await supabase.rpc('generate_doc_number', { p_doc_type: 'SO' })

      const subtotal = lines.reduce((sum, l) => sum + l.quantity * l.unit_price, 0)
      const taxAmount = lines.reduce(
        (sum, l) => sum + (l.quantity * l.unit_price * (l.tax_percent || 0)) / 100,
        0,
      )
      const discountAmount = subtotal * ((soData.discount_percent || 0) / 100)

      const { data: so, error: soError } = await supabase
        .from('sales_orders')
        .insert({
          ...soData,
          doc_number: docNum,
          subtotal,
          tax_amount: taxAmount,
          discount_amount: discountAmount,
          total_amount: subtotal + taxAmount - discountAmount,
        })
        .select()
        .single()

      if (soError) throw soError

      const soLines = lines.map((line, index) => ({
        so_id: so.id,
        line_num: index + 1,
        item_id: line.item_id,
        item_description: line.item_description,
        quantity: line.quantity,
        open_quantity: line.quantity,
        uom_id: line.uom_id,
        unit_price: line.unit_price,
        discount_percent: line.discount_percent || 0,
        tax_percent: line.tax_percent || 0,
        line_total: line.quantity * line.unit_price * (1 - (line.discount_percent || 0) / 100),
        warehouse_id: line.warehouse_id || soData.warehouse_id,
        status: 'open',
      }))

      const { error: linesError } = await supabase.from('sales_order_lines').insert(soLines)
      if (linesError) throw linesError

      await fetchSalesOrders()
      return { success: true, data: so }
    } catch (err) {
      console.error('Error creating sales order:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function approveSalesOrder(soId, approvedBy) {
    try {
      loading.value = true
      const { data, error: updateError } = await supabase
        .from('sales_orders')
        .update({
          status: 'approved',
          approved_by: approvedBy,
          approved_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', soId)
        .select()
        .single()

      if (updateError) throw updateError
      await fetchSalesOrders()
      return { success: true, data }
    } catch (err) {
      console.error('Error approving sales order:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // ============================================
  // DELIVERY DOCUMENTS
  // ============================================

  async function fetchDeliveryDocuments() {
    try {
      loading.value = true
      const { data, error: fetchError } = await supabase
        .from('delivery_documents')
        .select(
          `
          *,
          warehouse:warehouses(id, name, code),
          sales_order:sales_orders(id, doc_number),
          created_by_user:profiles!delivery_documents_created_by_fkey(full_name),
          delivery_document_lines(
            *,
            item:items(id, item_code, item_name),
            uom:units_of_measure(id, code, name)
          )
        `,
        )
        .order('created_at', { ascending: false })

      if (fetchError) throw fetchError
      deliveryDocuments.value = data
      return { success: true, data }
    } catch (err) {
      console.error('Error fetching delivery documents:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function createDeliveryDocument(delData, lines) {
    try {
      loading.value = true

      const { data: docNum } = await supabase.rpc('generate_doc_number', { p_doc_type: 'DEL' })

      const subtotal = lines.reduce((sum, l) => sum + l.quantity * (l.unit_price || 0), 0)

      const { data: del, error: delError } = await supabase
        .from('delivery_documents')
        .insert({
          ...delData,
          doc_number: docNum,
          subtotal,
          total_amount: subtotal,
        })
        .select()
        .single()

      if (delError) throw delError

      const delLines = lines.map((line, index) => ({
        delivery_id: del.id,
        line_num: index + 1,
        so_line_id: line.so_line_id,
        item_id: line.item_id,
        item_description: line.item_description,
        quantity: line.quantity,
        uom_id: line.uom_id,
        unit_cost: line.unit_cost,
        unit_price: line.unit_price,
        line_total: line.quantity * (line.unit_price || 0),
        warehouse_id: line.warehouse_id || delData.warehouse_id,
        bin_location_id: line.bin_location_id,
        batch_number: line.batch_number,
      }))

      const { error: linesError } = await supabase.from('delivery_document_lines').insert(delLines)
      if (linesError) throw linesError

      await fetchDeliveryDocuments()
      return { success: true, data: del }
    } catch (err) {
      console.error('Error creating delivery document:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function postDeliveryDocument(delId, deliveredBy) {
    try {
      loading.value = true
      const { data, error: updateError } = await supabase
        .from('delivery_documents')
        .update({
          status: 'posted',
          delivered_by: deliveredBy,
          delivered_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', delId)
        .select()
        .single()

      if (updateError) throw updateError
      await fetchDeliveryDocuments()
      return { success: true, data }
    } catch (err) {
      console.error('Error posting delivery document:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // ============================================
  // STOCK AUDIT TRAIL (OINM)
  // ============================================

  async function fetchStockAuditTrail(filters = {}) {
    try {
      loading.value = true
      let query = supabase
        .from('stock_transactions')
        .select(
          `
          *,
          item:items(id, item_code, item_name),
          warehouse:warehouses(id, name, code),
          bin_location:bin_locations(id, bin_code),
          created_by_user:profiles!stock_transactions_created_by_fkey(full_name)
        `,
        )
        .order('created_at', { ascending: false })
        .limit(500)

      if (filters.item_id) query = query.eq('item_id', filters.item_id)
      if (filters.warehouse_id) query = query.eq('warehouse_id', filters.warehouse_id)
      if (filters.doc_type) query = query.eq('doc_type', filters.doc_type)
      if (filters.from_date) query = query.gte('transaction_date', filters.from_date)
      if (filters.to_date) query = query.lte('transaction_date', filters.to_date)

      const { data, error: fetchError } = await query
      if (fetchError) throw fetchError
      stockAuditTrail.value = data
      return { success: true, data }
    } catch (err) {
      console.error('Error fetching stock audit trail:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // ============================================
  // JOURNAL ENTRIES
  // ============================================

  async function fetchJournalEntries(filters = {}) {
    try {
      loading.value = true
      let query = supabase
        .from('journal_entries')
        .select(
          `
          *,
          created_by_user:profiles!journal_entries_created_by_fkey(full_name),
          journal_entry_lines(*)
        `,
        )
        .order('created_at', { ascending: false })
        .limit(200)

      if (filters.source_type) query = query.eq('source_type', filters.source_type)
      if (filters.from_date) query = query.gte('posting_date', filters.from_date)
      if (filters.to_date) query = query.lte('posting_date', filters.to_date)

      const { data, error: fetchError } = await query
      if (fetchError) throw fetchError
      journalEntries.value = data
      return { success: true, data }
    } catch (err) {
      console.error('Error fetching journal entries:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // ============================================
  // INITIALIZATION
  // ============================================

  async function initializeInventoryStore() {
    try {
      loading.value = true
      error.value = null

      await Promise.all([
        fetchBinLocations(),
        fetchPriceLists(),
        fetchCycleCounts(),
        fetchPickLists(),
        fetchSalesOrders(),
        fetchDeliveryDocuments(),
      ])
    } catch (err) {
      console.error('Error initializing inventory store:', err)
      error.value = err.message
    } finally {
      loading.value = false
    }
  }

  function clearError() {
    error.value = null
  }

  // ============================================
  // EXPORTS
  // ============================================

  return {
    // State
    binLocations,
    binStock,
    cycleCounts,
    currentCycleCount,
    pickLists,
    currentPickList,
    priceLists,
    priceListItems,
    salesOrders,
    deliveryDocuments,
    stockAuditTrail,
    journalEntries,
    loading,
    error,

    // Getters
    activeBinLocations,
    activePriceLists,
    defaultPriceList,
    pendingSalesOrders,
    openPickLists,
    pendingCycleCounts,

    // Bin Locations
    fetchBinLocations,
    createBinLocation,
    updateBinLocation,

    // Cycle Counting
    fetchCycleCounts,
    createCycleCount,
    updateCycleCountLine,
    completeCycleCount,

    // Pick & Pack
    fetchPickLists,
    createPickList,
    updatePickListLine,

    // Price Lists
    fetchPriceLists,
    createPriceList,
    fetchPriceListItems,
    addPriceListItem,
    getItemPrice,

    // Sales Orders
    fetchSalesOrders,
    createSalesOrder,
    approveSalesOrder,

    // Delivery Documents
    fetchDeliveryDocuments,
    createDeliveryDocument,
    postDeliveryDocument,

    // Stock Audit Trail
    fetchStockAuditTrail,

    // Journal Entries
    fetchJournalEntries,

    // Init
    initializeInventoryStore,
    clearError,
  }
})
