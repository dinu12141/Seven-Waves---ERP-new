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
  const recipes = ref([])
  const stockTransfers = ref([])

  // UI State
  const loading = ref(false)
  const error = ref(null)

  // ============================================
  // GETTERS
  // ============================================

  const activeItems = computed(() => items.value.filter((i) => i.is_active))

  // Item Type Getters
  const inventoryItems = computed(() =>
    items.value.filter((i) => i.is_active && i.is_inventory_item),
  )
  const salesItems = computed(() => items.value.filter((i) => i.is_active && i.is_sales_item))
  const purchaseItems = computed(() => items.value.filter((i) => i.is_active && i.is_purchase_item))
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

  const activeRecipes = computed(() => recipes.value.filter((r) => r.is_active))

  const pendingTransfers = computed(() => stockTransfers.value.filter((t) => t.status === 'draft'))

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

      // 0. Strict Payload Whitelist (Prevent 400 Errors)
      // Note: Commenting out fields that might be missing if migration 05 is not run
      const allowedFields = [
        'item_code',
        'item_name',
        'category_id',
        'base_uom_id',
        'purchase_price',
        'selling_price',
        'description',
        'is_active',
        'is_inventory_item',
        'is_sales_item',
        'is_purchase_item',
        'min_stock_level',
        'max_stock_level',
        'reorder_point',
        'reorder_quantity',
        // 'manage_serial_numbers', 'manage_batch_numbers',
        // 'manufacturer', 'shipping_type', 'barcode',
        // 'item_type', 'valuation_method', 'procurement_method',
        // 'tax_group_id', 'uom_group_id'
      ]

      const payload = {}
      allowedFields.forEach((field) => {
        if (itemData[field] !== undefined) {
          payload[field] = itemData[field]
        }
      })

      // Remove foreign_name manually if it slipped through or if logic changes
      // This is double safety.
      const { opening_stock, opening_stock_warehouse_id } = itemData

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

      // Strict Update Whitelist
      // Note: Commenting out fields that might be missing if migration 05 is not run
      const allowedUpdates = [
        'item_name',
        'category_id',
        'base_uom_id',
        'purchase_price',
        'selling_price',
        'description',
        'is_active',
        'is_inventory_item',
        'is_sales_item',
        'is_purchase_item',
        'min_stock_level',
        'max_stock_level',
        'reorder_point',
        'reorder_quantity',
        // 'manage_serial_numbers', 'manage_batch_numbers',
        // 'manufacturer', 'shipping_type', 'barcode',
        // 'item_type', 'valuation_method', 'procurement_method',
        // 'tax_group_id', 'uom_group_id'
      ]

      const payload = {}
      allowedUpdates.forEach((field) => {
        if (updates[field] !== undefined) {
          payload[field] = updates[field]
        }
      })
      // Always update timestamp
      payload.updated_at = new Date().toISOString()

      const { error: updateError } = await supabase
        .from('items')
        .update(payload)
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

      if (rpcError) {
        console.warn('RPC generate_doc_number failed, using fallback:', rpcError)
        // Fallback to client-side generation
        const timestamp = Date.now()
        const random = Math.floor(Math.random() * 1000)
          .toString()
          .padStart(3, '0')
        const docNumber = `${docType}-${timestamp}-${random}`
        return { success: true, docNumber }
      }

      return { success: true, docNumber: data }
    } catch (err) {
      console.error('Error generating doc number:', err)
      // Emergency fallback
      const timestamp = Date.now()
      const random = Math.floor(Math.random() * 1000)
        .toString()
        .padStart(3, '0')
      const docNumber = `${docType}-${timestamp}-${random}`
      return { success: true, docNumber }
    }
  }

  async function getNextItemCode(prefix) {
    try {
      const { data, error: rpcError } = await supabase.rpc('generate_next_item_code', {
        p_prefix: prefix,
      })

      if (rpcError) throw rpcError

      return { success: true, code: data }
    } catch (err) {
      console.error('Error generating item code:', err)
      // Fallback
      const random = Math.floor(Math.random() * 10000)
        .toString()
        .padStart(4, '0')
      return { success: true, code: `${prefix}-${random}` }
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

      // Manually fetch creator profiles
      const userIds = [
        ...new Set(
          data
            .map((r) => r.created_by)
            .concat(data.map((r) => r.approved_by))
            .filter(Boolean),
        ),
      ]
      if (userIds.length > 0) {
        const { data: profiles } = await supabase
          .from('profiles')
          .select('id, full_name')
          .in('id', userIds)

        if (profiles) {
          const profileMap = Object.fromEntries(profiles.map((p) => [p.id, p]))
          data.forEach((r) => {
            if (r.created_by) r.created_by_user = profileMap[r.created_by]
            if (r.approved_by) r.approved_by_user = profileMap[r.approved_by]
          })
        }
      }

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

      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) throw new Error('User not authenticated')

      const { data, error: rpcError } = await supabase.rpc('process_goods_receipt_po', {
        p_grn_header: grnData,
        p_grn_lines: lines,
        p_user_id: user.id,
      })

      if (rpcError) throw rpcError
      if (!data.success) throw new Error(data.error)

      await Promise.all([
        fetchGoodsReceiptNotes(),
        fetchItems(), // Refresh costs
        fetchPurchaseOrders(), // Refresh status
      ])

      return { success: true, data: { id: data.grn_id, doc_number: data.doc_number } }
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
          gin_lines(
            *,
            item:items(id, item_code, item_name),
            uom:units_of_measure(id, code, name)
          )
        `,
        )
        .order('created_at', { ascending: false })

      if (fetchError) throw fetchError

      // Manually fetch creator profiles
      const userIds = [
        ...new Set(
          data
            .map((r) => r.created_by)
            .concat(data.map((r) => r.approved_by))
            .filter(Boolean),
        ),
      ]
      if (userIds.length > 0) {
        const { data: profiles } = await supabase
          .from('profiles')
          .select('id, full_name')
          .in('id', userIds)

        if (profiles) {
          const profileMap = Object.fromEntries(profiles.map((p) => [p.id, p]))
          data.forEach((r) => {
            if (r.created_by) r.created_by_user = profileMap[r.created_by]
            if (r.approved_by) r.approved_by_user = profileMap[r.approved_by]
          })
        }
      }

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
  // RECIPE / BOM ACTIONS
  // ============================================

  async function fetchRecipes() {
    try {
      loading.value = true
      const { data, error: fetchError } = await supabase
        .from('recipes')
        .select(
          `
          *,
          sales_item:items(id, item_code, item_name),
          target_warehouse:warehouses(id, name, code),
          yield_uom:units_of_measure(id, code, name),
          recipe_lines(
            *,
            item:items(id, item_code, item_name, is_purchase_item),
            uom:units_of_measure(id, code, name)
          )
        `,
        )
        .order('created_at', { ascending: false })

      if (fetchError) throw fetchError

      // Manually fetch creator profiles
      const userIds = [...new Set(data.map((r) => r.created_by).filter(Boolean))]
      if (userIds.length > 0) {
        const { data: profiles } = await supabase
          .from('profiles')
          .select('id, full_name')
          .in('id', userIds)

        if (profiles) {
          const profileMap = Object.fromEntries(profiles.map((p) => [p.id, p]))
          data.forEach((r) => {
            if (r.created_by) {
              r.created_by_user = profileMap[r.created_by]
            }
          })
        }
      }

      recipes.value = data
      return { success: true, data }
    } catch (err) {
      console.error('Error fetching recipes:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function createRecipe(recipeData, lines) {
    try {
      loading.value = true

      // Generate recipe code
      const docResult = await generateDocNumber('RCP')
      if (!docResult.success) throw new Error(docResult.error)

      // Create recipe header
      const { data: recipe, error: recipeError } = await supabase
        .from('recipes')
        .insert({
          ...recipeData,
          recipe_code: docResult.docNumber,
        })
        .select()
        .single()

      if (recipeError) throw recipeError

      // Create recipe lines with cost calculation
      const recipeLines = lines.map((line, index) => ({
        recipe_id: recipe.id,
        line_num: index + 1,
        item_id: line.item_id,
        quantity: line.quantity,
        uom_id: line.uom_id,
        unit_cost: line.unit_cost || 0,
        line_total: line.quantity * (line.unit_cost || 0),
        notes: line.notes,
      }))

      const { error: linesError } = await supabase.from('recipe_lines').insert(recipeLines)

      if (linesError) throw linesError

      await fetchRecipes()
      return { success: true, data: recipe }
    } catch (err) {
      console.error('Error creating recipe:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function updateRecipe(id, updates, lines = null) {
    try {
      loading.value = true
      const { data, error: updateError } = await supabase
        .from('recipes')
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single()

      if (updateError) throw updateError

      // Update lines if provided
      if (lines) {
        // Delete existing lines
        await supabase.from('recipe_lines').delete().eq('recipe_id', id)

        // Insert new lines
        const recipeLines = lines.map((line, index) => ({
          recipe_id: id,
          line_num: index + 1,
          item_id: line.item_id,
          quantity: line.quantity,
          uom_id: line.uom_id,
          unit_cost: line.unit_cost || 0,
          line_total: line.quantity * (line.unit_cost || 0),
          notes: line.notes,
        }))

        const { error: linesError } = await supabase.from('recipe_lines').insert(recipeLines)
        if (linesError) throw linesError
      }

      await fetchRecipes()
      return { success: true, data }
    } catch (err) {
      console.error('Error updating recipe:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function deleteRecipe(id) {
    try {
      loading.value = true
      const { error: deleteError } = await supabase.from('recipes').delete().eq('id', id)

      if (deleteError) throw deleteError
      recipes.value = recipes.value.filter((r) => r.id !== id)
      return { success: true }
    } catch (err) {
      console.error('Error deleting recipe:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function calculateRecipeCost(recipeId) {
    try {
      // Get recipe with lines
      const recipe = recipes.value.find((r) => r.id === recipeId)
      if (!recipe || !recipe.recipe_lines) {
        return { success: false, error: 'Recipe not found' }
      }

      let totalCost = 0

      // Calculate cost for each ingredient
      for (const line of recipe.recipe_lines) {
        // Get current average cost from warehouse_stock for the target warehouse
        const { data: stockData } = await supabase
          .from('warehouse_stock')
          .select('average_cost')
          .eq('item_id', line.item_id)
          .eq('warehouse_id', recipe.target_warehouse_id)
          .single()

        const avgCost = stockData?.average_cost || line.unit_cost || 0
        totalCost += line.quantity * avgCost
      }

      return { success: true, totalCost }
    } catch (err) {
      console.error('Error calculating recipe cost:', err)
      return { success: false, error: err.message }
    }
  }

  // ============================================
  // STOCK TRANSFER ACTIONS
  // ============================================

  async function fetchStockTransfers() {
    try {
      loading.value = true
      const { data, error: fetchError } = await supabase
        .from('stock_transfers')
        .select(
          `
          *,
          from_warehouse:warehouses!stock_transfers_from_warehouse_id_fkey(id, name, code),
          to_warehouse:warehouses!stock_transfers_to_warehouse_id_fkey(id, name, code),
          stock_transfer_lines(
            *,
            item:items(id, item_code, item_name),
            uom:units_of_measure(id, code, name)
          )
        `,
        )
        .order('created_at', { ascending: false })

      if (fetchError) throw fetchError

      // Manually fetch related profiles
      const userIds = [
        ...new Set(
          [...data.map((t) => t.created_by), ...data.map((t) => t.approved_by)].filter(Boolean),
        ),
      ]

      if (userIds.length > 0) {
        const { data: profiles } = await supabase
          .from('profiles')
          .select('id, full_name')
          .in('id', userIds)

        if (profiles) {
          const profileMap = Object.fromEntries(profiles.map((p) => [p.id, p]))
          data.forEach((t) => {
            if (t.created_by) t.created_by_user = profileMap[t.created_by]
            if (t.approved_by) t.approved_by_user = profileMap[t.approved_by]
          })
        }
      }

      stockTransfers.value = data
      return { success: true, data }
    } catch (err) {
      console.error('Error fetching stock transfers:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function createStockTransfer(transferData, lines) {
    try {
      loading.value = true

      // Generate document number
      const docResult = await generateDocNumber('STR')
      if (!docResult.success) throw new Error(docResult.error)

      // Calculate total cost
      const totalCost = lines.reduce((sum, line) => sum + line.quantity * (line.unit_cost || 0), 0)

      // Create transfer header
      const { data: transfer, error: transferError } = await supabase
        .from('stock_transfers')
        .insert({
          ...transferData,
          doc_number: docResult.docNumber,
          total_cost: totalCost,
        })
        .select()
        .single()

      if (transferError) throw transferError

      // Create transfer lines
      const transferLines = lines.map((line, index) => ({
        transfer_id: transfer.id,
        line_num: index + 1,
        item_id: line.item_id,
        item_description: line.item_description,
        quantity: line.quantity,
        uom_id: line.uom_id,
        unit_cost: line.unit_cost || 0,
        line_total: line.quantity * (line.unit_cost || 0),
      }))

      const { error: linesError } = await supabase
        .from('stock_transfer_lines')
        .insert(transferLines)

      if (linesError) throw linesError

      await fetchStockTransfers()
      return { success: true, data: transfer }
    } catch (err) {
      console.error('Error creating stock transfer:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function completeStockTransfer(transferId, approvedBy) {
    try {
      loading.value = true
      const { data, error: updateError } = await supabase
        .from('stock_transfers')
        .update({
          status: 'completed',
          approved_by: approvedBy,
          approved_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', transferId)
        .select()
        .single()

      if (updateError) throw updateError

      // Trigger will handle stock updates
      await Promise.all([fetchStockTransfers(), fetchItems()])

      return { success: true, data }
    } catch (err) {
      console.error('Error completing stock transfer:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function cancelStockTransfer(transferId) {
    try {
      loading.value = true
      const { data, error: updateError } = await supabase
        .from('stock_transfers')
        .update({
          status: 'cancelled',
          updated_at: new Date().toISOString(),
        })
        .eq('id', transferId)
        .select()
        .single()

      if (updateError) throw updateError

      const index = stockTransfers.value.findIndex((t) => t.id === transferId)
      if (index !== -1) {
        stockTransfers.value[index] = { ...stockTransfers.value[index], ...data }
      }

      return { success: true, data }
    } catch (err) {
      console.error('Error cancelling stock transfer:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  function clearError() {
    error.value = null
  }

  // ============================================
  // PURCHASE REQUEST ACTIONS
  // ============================================

  const purchaseRequests = ref([])
  const alerts = ref([])

  async function fetchPurchaseRequests() {
    try {
      loading.value = true
      const { data, error: fetchError } = await supabase
        .from('purchase_requests')
        .select(
          `
          *,
          requester:profiles!purchase_requests_requester_id_fkey(full_name),
          purchase_request_lines(
            *,
            item:items(id, item_code, item_name, default_supplier_id),
            uom:units_of_measure(id, code, name),
            preferred_vendor:suppliers(id, name)
          )
        `,
        )
        .order('created_at', { ascending: false })

      if (fetchError) throw fetchError
      purchaseRequests.value = data
    } catch (err) {
      console.error('Error fetching PRs:', err)
      error.value = err.message
    } finally {
      loading.value = false
    }
  }

  async function createPurchaseRequest(prData, lines) {
    try {
      loading.value = true
      const docResult = await generateDocNumber('PRQ')
      if (!docResult.success) throw new Error(docResult.error)

      const { data: pr, error: prError } = await supabase
        .from('purchase_requests')
        .insert({ ...prData, doc_number: docResult.docNumber })
        .select()
        .single()

      if (prError) throw prError

      const prLines = lines.map((line) => ({
        request_id: pr.id,
        item_id: line.item_id,
        required_quantity: line.required_quantity,
        open_quantity: line.required_quantity,
        uom_id: line.uom_id,
        preferred_vendor_id: line.preferred_vendor_id,
      }))

      const { error: linesError } = await supabase.from('purchase_request_lines').insert(prLines)
      if (linesError) throw linesError

      await fetchPurchaseRequests()
      return { success: true, data: pr }
    } catch (err) {
      console.error('Error creating PR:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // Check for items below MinStock
  async function checkStockAlerts() {
    try {
      // 1. Fetch items with stock info
      await fetchItems()

      const lowStockItems = items.value.filter((item) => {
        if (!item.is_inventory_item || !item.min_stock_level) return false

        // Formula: Available = In Stock + Ordered - Committed
        const inStock =
          item.warehouse_stock?.reduce((acc, ws) => acc + (ws.quantity_on_hand || 0), 0) || 0
        const ordered =
          item.warehouse_stock?.reduce((acc, ws) => acc + (ws.quantity_ordered || 0), 0) || 0
        const committed =
          item.warehouse_stock?.reduce((acc, ws) => acc + (ws.quantity_committed || 0), 0) || 0

        const available = inStock + ordered - committed

        return available < item.min_stock_level
      })

      alerts.value = lowStockItems.map((item) => ({
        item_id: item.id,
        item_code: item.item_code,
        item_name: item.item_name,
        min_stock: item.min_stock_level,
        available_stock:
          (item.warehouse_stock?.reduce((acc, ws) => acc + (ws.quantity_on_hand || 0), 0) || 0) +
          (item.warehouse_stock?.reduce((acc, ws) => acc + (ws.quantity_ordered || 0), 0) || 0) -
          (item.warehouse_stock?.reduce((acc, ws) => acc + (ws.quantity_committed || 0), 0) || 0),
        reorder_qty:
          item.reorder_quantity ||
          (item.max_stock_level ? item.max_stock_level - item.min_stock_level : 0),
        preferred_vendor_id: item.default_supplier_id,
      }))

      return alerts.value
    } catch (err) {
      console.error('Error checking alerts:', err)
      return []
    }
  }

  async function createPOFromPR(prId, poHeader, selectedLines) {
    // Implementation logic would go here
    return createPurchaseOrder(poHeader, selectedLines)
  }

  // ============================================
  // REALTIME SUBSCRIPTIONS
  // ============================================

  let realtimeChannel = null

  function subscribeToRealtime() {
    if (realtimeChannel) return realtimeChannel

    realtimeChannel = supabase
      .channel('stock-db-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'warehouse_stock' },
        (payload) => {
          console.log('Realtime Stock Update:', payload)
          fetchItems().then(() => checkStockAlerts()) // Refresh all items to update stock levels and related calculations
        },
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'purchase_orders' },
        (payload) => {
          console.log('Realtime PO Update:', payload)
          fetchPurchaseOrders()
        },
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'goods_receipt_notes' },
        (payload) => {
          console.log('Realtime GRN Update:', payload)
          fetchGoodsReceiptNotes()
        },
      )
      .subscribe()

    return realtimeChannel
  }

  function unsubscribeRealtime() {
    if (realtimeChannel) {
      supabase.removeChannel(realtimeChannel)
      realtimeChannel = null
    }
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
    recipes,
    stockTransfers,
    purchaseRequests,
    alerts,
    loading,
    error,

    // Getters
    activeItems,
    inventoryItems,
    salesItems,
    purchaseItems,
    activeWarehouses,
    activeSuppliers,
    activeCategories,
    defaultWarehouse,
    pendingPOs,
    pendingGRNs,
    activeRecipes,
    pendingTransfers,

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
    getNextItemCode,

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

    // Recipe/BOM Actions
    fetchRecipes,
    createRecipe,
    updateRecipe,
    deleteRecipe,
    calculateRecipeCost,

    // Stock Transfer Actions
    fetchStockTransfers,
    createStockTransfer,
    completeStockTransfer,
    cancelStockTransfer,

    // Procurement Actions (New)
    fetchPurchaseRequests,
    createPurchaseRequest,
    checkStockAlerts,
    createPOFromPR,

    // Realtime
    subscribeToRealtime,
    unsubscribeRealtime,

    // Init
    clearError,
  }
})
