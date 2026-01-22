import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from 'src/boot/supabase'

export const useStockStore = defineStore('stock', () => {
  // ============================================
  // STATE
  // ============================================

  // Master Data
  const items = ref([])
  const categories = ref([])
  const warehouses = ref([])
  const suppliers = ref([])
  const unitsOfMeasure = ref([])

  // Transaction Data
  const purchaseOrders = ref([])
  const goodsReceiptNotes = ref([])
  const goodsIssueNotes = ref([])
  const stockTransactions = ref([])

  // UI State
  const loading = ref(false)
  const error = ref(null)

  // ============================================
  // GETTERS
  // ============================================

  const activeItems = computed(() => items.value.filter((i) => i.is_active))
  const activeWarehouses = computed(() => warehouses.value.filter((w) => w.is_active))
  const activeSuppliers = computed(() => suppliers.value.filter((s) => s.is_active))
  const activeCategories = computed(() => categories.value.filter((c) => c.is_active))

  const defaultWarehouse = computed(
    () => warehouses.value.find((w) => w.is_default) || warehouses.value[0],
  )

  const pendingPOs = computed(() =>
    purchaseOrders.value.filter((po) => po.status === 'pending' || po.status === 'approved'),
  )

  const pendingGRNs = computed(() =>
    goodsReceiptNotes.value.filter((grn) => grn.status === 'pending'),
  )

  // ============================================
  // MASTER DATA ACTIONS
  // ============================================

  // --- Units of Measure ---
  async function fetchUnitsOfMeasure() {
    try {
      const { data, error: fetchError } = await supabase
        .from('units_of_measure')
        .select('*')
        .order('name')

      if (fetchError) throw fetchError
      unitsOfMeasure.value = data
    } catch (err) {
      console.error('Error fetching UoM:', err)
      error.value = err.message
    }
  }

  // --- Categories ---
  async function fetchCategories() {
    try {
      const { data, error: fetchError } = await supabase
        .from('item_categories')
        .select('*')
        .order('name')

      if (fetchError) throw fetchError
      categories.value = data
    } catch (err) {
      console.error('Error fetching categories:', err)
      error.value = err.message
    }
  }

  async function createCategory(categoryData) {
    try {
      loading.value = true
      const { data, error: insertError } = await supabase
        .from('item_categories')
        .insert(categoryData)
        .select()
        .single()

      if (insertError) throw insertError
      categories.value.push(data)
      return { success: true, data }
    } catch (err) {
      console.error('Error creating category:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // --- Warehouses ---
  async function fetchWarehouses() {
    try {
      const { data, error: fetchError } = await supabase
        .from('warehouses')
        .select('*, manager:profiles(full_name)')
        .order('name')

      if (fetchError) throw fetchError
      warehouses.value = data
    } catch (err) {
      console.error('Error fetching warehouses:', err)
      error.value = err.message
    }
  }

  async function createWarehouse(warehouseData) {
    try {
      loading.value = true
      const { data, error: insertError } = await supabase
        .from('warehouses')
        .insert(warehouseData)
        .select()
        .single()

      if (insertError) throw insertError
      warehouses.value.push(data)
      return { success: true, data }
    } catch (err) {
      console.error('Error creating warehouse:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function updateWarehouse(id, updates) {
    try {
      loading.value = true
      const { data, error: updateError } = await supabase
        .from('warehouses')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single()

      if (updateError) throw updateError
      const index = warehouses.value.findIndex((w) => w.id === id)
      if (index !== -1) warehouses.value[index] = data
      return { success: true, data }
    } catch (err) {
      console.error('Error updating warehouse:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // --- Suppliers ---
  async function fetchSuppliers() {
    try {
      const { data, error: fetchError } = await supabase.from('suppliers').select('*').order('name')

      if (fetchError) throw fetchError
      suppliers.value = data
    } catch (err) {
      console.error('Error fetching suppliers:', err)
      error.value = err.message
    }
  }

  async function createSupplier(supplierData) {
    try {
      loading.value = true
      const { data, error: insertError } = await supabase
        .from('suppliers')
        .insert(supplierData)
        .select()
        .single()

      if (insertError) throw insertError
      suppliers.value.push(data)
      return { success: true, data }
    } catch (err) {
      console.error('Error creating supplier:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function updateSupplier(id, updates) {
    try {
      loading.value = true
      const { data, error: updateError } = await supabase
        .from('suppliers')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single()

      if (updateError) throw updateError
      const index = suppliers.value.findIndex((s) => s.id === id)
      if (index !== -1) suppliers.value[index] = data
      return { success: true, data }
    } catch (err) {
      console.error('Error updating supplier:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // --- Items ---
  async function fetchItems() {
    try {
      loading.value = true
      const { data, error: fetchError } = await supabase
        .from('items')
        .select(
          `
          *,
          category:item_categories(id, name, code),
          base_uom:units_of_measure(id, code, name),
          default_warehouse:warehouses(id, name, code),
          default_supplier:suppliers(id, name, code),
          warehouse_stock(
            id,
            warehouse_id,
            quantity_on_hand,
            quantity_committed,
            quantity_ordered,
            average_cost,
            warehouse:warehouses(id, name, code)
          ),
          item_uom(
            id,
            uom_id,
            conversion_factor,
            is_default_purchase,
            is_default_sales,
            uom:units_of_measure(id, code, name)
          )
        `,
        )
        .order('item_name')

      if (fetchError) throw fetchError
      items.value = data
    } catch (err) {
      console.error('Error fetching items:', err)
      error.value = err.message
    } finally {
      loading.value = false
    }
  }

  async function fetchItemById(id) {
    try {
      const { data, error: fetchError } = await supabase
        .from('items')
        .select(
          `
          *,
          category:item_categories(id, name, code),
          base_uom:units_of_measure(id, code, name),
          default_warehouse:warehouses(id, name, code),
          default_supplier:suppliers(id, name, code),
          warehouse_stock(
            id,
            warehouse_id,
            quantity_on_hand,
            quantity_committed,
            quantity_ordered,
            average_cost,
            warehouse:warehouses(id, name, code)
          ),
          item_uom(
            id,
            uom_id,
            conversion_factor,
            is_default_purchase,
            is_default_sales,
            uom:units_of_measure(id, code, name)
          )
        `,
        )
        .eq('id', id)
        .single()

      if (fetchError) throw fetchError
      return { success: true, data }
    } catch (err) {
      console.error('Error fetching item:', err)
      return { success: false, error: err.message }
    }
  }

  async function createItem(itemData) {
    try {
      loading.value = true

      // Extract opening stock data
      const { opening_stock, opening_stock_warehouse_id, ...payload } = itemData

      const { data, error: insertError } = await supabase
        .from('items')
        .insert(payload)
        .select()
        .single()

      if (insertError) throw insertError

      // Handle Opening Stock
      if (opening_stock > 0 && opening_stock_warehouse_id) {
        try {
          // 1. Create Stock Entry
          const { error: stockError } = await supabase.from('warehouse_stock').insert({
            item_id: data.id,
            warehouse_id: opening_stock_warehouse_id,
            quantity_on_hand: opening_stock,
            average_cost: payload.purchase_price || 0,
          })

          if (stockError) throw stockError

          // 2. Create Transaction Record
          await supabase.from('stock_transactions').insert({
            item_id: data.id,
            warehouse_id: opening_stock_warehouse_id,
            transaction_type: 'opening_balance',
            quantity: opening_stock,
            transaction_date: new Date().toISOString(),
            doc_number: `OP-${data.item_code}`,
            notes: 'Initial opening stock',
          })
        } catch (stockErr) {
          console.error('Error creating opening stock:', stockErr)
          // We don't fail the whole operation, but we should probably warn
        }
      }

      // Fetch full item with relations
      const result = await fetchItemById(data.id)
      if (result.success) {
        items.value.push(result.data)
      }

      return { success: true, data }
    } catch (err) {
      console.error('Error creating item:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function updateItem(id, updates) {
    try {
      loading.value = true
      const { error: updateError } = await supabase
        .from('items')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single()

      if (updateError) throw updateError

      // Fetch full item with relations
      const result = await fetchItemById(id)
      if (result.success) {
        const index = items.value.findIndex((i) => i.id === id)
        if (index !== -1) items.value[index] = result.data
      }

      return { success: true, data: result.data }
    } catch (err) {
      console.error('Error updating item:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function deleteItem(id) {
    try {
      loading.value = true
      const { error: deleteError } = await supabase.from('items').delete().eq('id', id)

      if (deleteError) throw deleteError
      items.value = items.value.filter((i) => i.id !== id)
      return { success: true }
    } catch (err) {
      console.error('Error deleting item:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // --- Item UoM ---
  async function addItemUom(itemId, uomData) {
    try {
      const { data, error: insertError } = await supabase
        .from('item_uom')
        .insert({ item_id: itemId, ...uomData })
        .select('*, uom:units_of_measure(id, code, name)')
        .single()

      if (insertError) throw insertError

      const item = items.value.find((i) => i.id === itemId)
      if (item) {
        if (!item.item_uom) item.item_uom = []
        item.item_uom.push(data)
      }

      return { success: true, data }
    } catch (err) {
      console.error('Error adding item UoM:', err)
      return { success: false, error: err.message }
    }
  }

  // ============================================
  // DOCUMENT NUMBER GENERATION
  // ============================================

  async function generateDocNumber(docType) {
    try {
      const { data, error: rpcError } = await supabase.rpc('generate_doc_number', {
        p_doc_type: docType,
      })

      if (rpcError) throw rpcError
      return { success: true, docNumber: data }
    } catch (err) {
      console.error('Error generating doc number:', err)
      return { success: false, error: err.message }
    }
  }

  // ============================================
  // PURCHASE ORDER ACTIONS
  // ============================================

  async function fetchPurchaseOrders() {
    try {
      loading.value = true
      const { data, error: fetchError } = await supabase
        .from('purchase_orders')
        .select(
          `
          *,
          supplier:suppliers(id, name, code),
          warehouse:warehouses(id, name, code),
          created_by_user:profiles!purchase_orders_created_by_fkey(full_name),
          approved_by_user:profiles!purchase_orders_approved_by_fkey(full_name),
          po_lines(
            *,
            item:items(id, item_code, item_name),
            uom:units_of_measure(id, code, name)
          )
        `,
        )
        .order('created_at', { ascending: false })

      if (fetchError) throw fetchError
      purchaseOrders.value = data
    } catch (err) {
      console.error('Error fetching POs:', err)
      error.value = err.message
    } finally {
      loading.value = false
    }
  }

  async function createPurchaseOrder(poData, lines) {
    try {
      loading.value = true

      // Generate document number
      const docResult = await generateDocNumber('PO')
      if (!docResult.success) throw new Error(docResult.error)

      // Calculate totals
      const subtotal = lines.reduce((sum, line) => sum + line.quantity * line.unit_price, 0)
      const taxAmount = lines.reduce(
        (sum, line) => sum + (line.quantity * line.unit_price * (line.tax_percent || 0)) / 100,
        0,
      )
      const discountAmount = lines.reduce(
        (sum, line) => sum + (line.quantity * line.unit_price * (line.discount_percent || 0)) / 100,
        0,
      )

      // Create PO header
      const { data: po, error: poError } = await supabase
        .from('purchase_orders')
        .insert({
          ...poData,
          doc_number: docResult.docNumber,
          subtotal,
          tax_amount: taxAmount,
          discount_amount: discountAmount,
          total_amount: subtotal + taxAmount - discountAmount,
        })
        .select()
        .single()

      if (poError) throw poError

      // Create PO lines
      const poLines = lines.map((line, index) => ({
        po_id: po.id,
        line_num: index + 1,
        item_id: line.item_id,
        item_description: line.item_description,
        quantity: line.quantity,
        uom_id: line.uom_id,
        unit_price: line.unit_price,
        discount_percent: line.discount_percent || 0,
        tax_percent: line.tax_percent || 0,
        line_total: line.quantity * line.unit_price * (1 - (line.discount_percent || 0) / 100),
        warehouse_id: line.warehouse_id || poData.warehouse_id,
      }))

      const { error: linesError } = await supabase.from('po_lines').insert(poLines)

      if (linesError) throw linesError

      await fetchPurchaseOrders()
      return { success: true, data: po }
    } catch (err) {
      console.error('Error creating PO:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function approvePurchaseOrder(poId, approvedBy) {
    try {
      loading.value = true
      const { data, error: updateError } = await supabase
        .from('purchase_orders')
        .update({
          status: 'approved',
          approved_by: approvedBy,
          approved_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', poId)
        .select()
        .single()

      if (updateError) throw updateError

      const index = purchaseOrders.value.findIndex((po) => po.id === poId)
      if (index !== -1) {
        purchaseOrders.value[index] = { ...purchaseOrders.value[index], ...data }
      }

      return { success: true, data }
    } catch (err) {
      console.error('Error approving PO:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // ============================================
  // GOODS RECEIPT NOTE ACTIONS
  // ============================================

  async function fetchGoodsReceiptNotes() {
    try {
      loading.value = true
      const { data, error: fetchError } = await supabase
        .from('goods_receipt_notes')
        .select(
          `
          *,
          supplier:suppliers(id, name, code),
          warehouse:warehouses(id, name, code),
          purchase_order:purchase_orders(id, doc_number),
          created_by_user:profiles!goods_receipt_notes_created_by_fkey(full_name),
          approved_by_user:profiles!goods_receipt_notes_approved_by_fkey(full_name),
          grn_lines(
            *,
            item:items(id, item_code, item_name),
            uom:units_of_measure(id, code, name),
            po_line:po_lines(id, quantity, received_quantity)
          )
        `,
        )
        .order('created_at', { ascending: false })

      if (fetchError) throw fetchError
      goodsReceiptNotes.value = data
    } catch (err) {
      console.error('Error fetching GRNs:', err)
      error.value = err.message
    } finally {
      loading.value = false
    }
  }

  async function createGoodsReceiptNote(grnData, lines) {
    try {
      loading.value = true

      // Generate document number
      const docResult = await generateDocNumber('GRN')
      if (!docResult.success) throw new Error(docResult.error)

      // Calculate totals
      const subtotal = lines.reduce((sum, line) => sum + line.quantity * line.unit_cost, 0)

      // Create GRN header
      const { data: grn, error: grnError } = await supabase
        .from('goods_receipt_notes')
        .insert({
          ...grnData,
          doc_number: docResult.docNumber,
          subtotal,
          total_amount: subtotal,
        })
        .select()
        .single()

      if (grnError) throw grnError

      // Create GRN lines
      const grnLines = lines.map((line, index) => ({
        grn_id: grn.id,
        line_num: index + 1,
        po_line_id: line.po_line_id,
        item_id: line.item_id,
        item_description: line.item_description,
        quantity: line.quantity,
        uom_id: line.uom_id,
        unit_cost: line.unit_cost,
        line_total: line.quantity * line.unit_cost,
        warehouse_id: line.warehouse_id || grnData.warehouse_id,
        batch_number: line.batch_number,
        expiry_date: line.expiry_date,
      }))

      const { error: linesError } = await supabase.from('grn_lines').insert(grnLines)

      if (linesError) throw linesError

      await fetchGoodsReceiptNotes()
      return { success: true, data: grn }
    } catch (err) {
      console.error('Error creating GRN:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function completeGoodsReceiptNote(grnId, approvedBy) {
    try {
      loading.value = true
      const { data, error: updateError } = await supabase
        .from('goods_receipt_notes')
        .update({
          status: 'completed',
          approved_by: approvedBy,
          approved_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', grnId)
        .select()
        .single()

      if (updateError) throw updateError

      // Refresh data (trigger will have updated stock)
      await Promise.all([fetchGoodsReceiptNotes(), fetchItems()])

      return { success: true, data }
    } catch (err) {
      console.error('Error completing GRN:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // ============================================
  // GOODS ISSUE NOTE ACTIONS
  // ============================================

  async function fetchGoodsIssueNotes() {
    try {
      loading.value = true
      const { data, error: fetchError } = await supabase
        .from('goods_issue_notes')
        .select(
          `
          *,
          from_warehouse:warehouses!goods_issue_notes_from_warehouse_id_fkey(id, name, code),
          to_warehouse:warehouses!goods_issue_notes_to_warehouse_id_fkey(id, name, code),
          created_by_user:profiles!goods_issue_notes_created_by_fkey(full_name),
          approved_by_user:profiles!goods_issue_notes_approved_by_fkey(full_name),
          gin_lines(
            *,
            item:items(id, item_code, item_name),
            uom:units_of_measure(id, code, name)
          )
        `,
        )
        .order('created_at', { ascending: false })

      if (fetchError) throw fetchError
      goodsIssueNotes.value = data
    } catch (err) {
      console.error('Error fetching GINs:', err)
      error.value = err.message
    } finally {
      loading.value = false
    }
  }

  async function createGoodsIssueNote(ginData, lines) {
    try {
      loading.value = true

      // Generate document number
      const docResult = await generateDocNumber('GIN')
      if (!docResult.success) throw new Error(docResult.error)

      // Calculate total cost
      const totalCost = lines.reduce((sum, line) => sum + line.quantity * (line.unit_cost || 0), 0)

      // Create GIN header
      const { data: gin, error: ginError } = await supabase
        .from('goods_issue_notes')
        .insert({
          ...ginData,
          doc_number: docResult.docNumber,
          total_cost: totalCost,
        })
        .select()
        .single()

      if (ginError) throw ginError

      // Create GIN lines
      const ginLines = lines.map((line, index) => ({
        gin_id: gin.id,
        line_num: index + 1,
        item_id: line.item_id,
        item_description: line.item_description,
        quantity: line.quantity,
        uom_id: line.uom_id,
        unit_cost: line.unit_cost || 0,
        line_total: line.quantity * (line.unit_cost || 0),
        from_warehouse_id: ginData.from_warehouse_id,
        to_warehouse_id: ginData.to_warehouse_id,
      }))

      const { error: linesError } = await supabase.from('gin_lines').insert(ginLines)

      if (linesError) throw linesError

      await fetchGoodsIssueNotes()
      return { success: true, data: gin }
    } catch (err) {
      console.error('Error creating GIN:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function completeGoodsIssueNote(ginId, approvedBy) {
    try {
      loading.value = true
      const { data, error: updateError } = await supabase
        .from('goods_issue_notes')
        .update({
          status: 'completed',
          approved_by: approvedBy,
          approved_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', ginId)
        .select()
        .single()

      if (updateError) throw updateError

      // Refresh data (trigger will have updated stock)
      await Promise.all([fetchGoodsIssueNotes(), fetchItems()])

      return { success: true, data }
    } catch (err) {
      console.error('Error completing GIN:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // ============================================
  // STOCK TRANSACTIONS
  // ============================================

  async function fetchStockTransactions(filters = {}) {
    try {
      let query = supabase
        .from('stock_transactions')
        .select(
          `
          *,
          item:items(id, item_code, item_name),
          warehouse:warehouses(id, name, code)
        `,
        )
        .order('transaction_date', { ascending: false })
        .limit(100)

      if (filters.item_id) {
        query = query.eq('item_id', filters.item_id)
      }
      if (filters.warehouse_id) {
        query = query.eq('warehouse_id', filters.warehouse_id)
      }
      if (filters.doc_type) {
        query = query.eq('doc_type', filters.doc_type)
      }

      const { data, error: fetchError } = await query

      if (fetchError) throw fetchError
      stockTransactions.value = data
      return { success: true, data }
    } catch (err) {
      console.error('Error fetching stock transactions:', err)
      return { success: false, error: err.message }
    }
  }

  // ============================================
  // REALTIME SUBSCRIPTIONS
  // ============================================

  let itemsSubscription = null
  let stockSubscription = null

  function setupRealtimeSubscriptions() {
    // Items subscription
    itemsSubscription = supabase
      .channel('items-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'items' }, async () => {
        await fetchItems()
      })
      .subscribe()

    // Warehouse stock subscription
    stockSubscription = supabase
      .channel('stock-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'warehouse_stock' },
        async () => {
          await fetchItems()
        },
      )
      .subscribe()
  }

  function cleanupSubscriptions() {
    if (itemsSubscription) {
      supabase.removeChannel(itemsSubscription)
      itemsSubscription = null
    }
    if (stockSubscription) {
      supabase.removeChannel(stockSubscription)
      stockSubscription = null
    }
  }

  // ============================================
  // INITIALIZATION
  // ============================================

  async function initializeStore() {
    try {
      loading.value = true
      error.value = null

      await Promise.all([
        fetchUnitsOfMeasure(),
        fetchCategories(),
        fetchWarehouses(),
        fetchSuppliers(),
        fetchItems(),
      ])

      setupRealtimeSubscriptions()
    } catch (err) {
      console.error('Error initializing stock store:', err)
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
    items,
    categories,
    warehouses,
    suppliers,
    unitsOfMeasure,
    purchaseOrders,
    goodsReceiptNotes,
    goodsIssueNotes,
    stockTransactions,
    loading,
    error,

    // Getters
    activeItems,
    activeWarehouses,
    activeSuppliers,
    activeCategories,
    defaultWarehouse,
    pendingPOs,
    pendingGRNs,

    // Master Data Actions
    fetchUnitsOfMeasure,
    fetchCategories,
    createCategory,
    fetchWarehouses,
    createWarehouse,
    updateWarehouse,
    fetchSuppliers,
    createSupplier,
    updateSupplier,
    fetchItems,
    fetchItemById,
    createItem,
    updateItem,
    deleteItem,
    addItemUom,

    // Document Generation
    generateDocNumber,

    // PO Actions
    fetchPurchaseOrders,
    createPurchaseOrder,
    approvePurchaseOrder,

    // GRN Actions
    fetchGoodsReceiptNotes,
    createGoodsReceiptNote,
    completeGoodsReceiptNote,

    // GIN Actions
    fetchGoodsIssueNotes,
    createGoodsIssueNote,
    completeGoodsIssueNote,

    // Stock Transactions
    fetchStockTransactions,

    // Realtime
    setupRealtimeSubscriptions,
    cleanupSubscriptions,

    // Init
    initializeStore,
    clearError,
  }
})
