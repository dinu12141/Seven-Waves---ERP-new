# GRN Fix - Step by Step Guide

## Problem

Previously created GRNs still show their POs in the dropdown, allowing duplicate GRNs.

## Root Cause

1. The `process_goods_receipt_po` RPC function wasn't updating `po_lines.received_quantity`
2. Wrong column name used (`po_id` instead of `purchase_order_id`)
3. No logic to mark POs as "completed" when fully received

## Solution Applied

### Files Created:

1. `003_fix_grn_processing.sql` - Main fix migration
2. `reset_grn_test_data.sql` - Optional reset script for testing

### What Changed:

- ✅ RPC function now updates `received_quantity` on each PO line
- ✅ PO status changes to "completed" when all lines fully received
- ✅ Frontend filter only shows POs with `received_quantity < ordered_quantity`
- ✅ Fixed column name mismatch (`purchase_order_id`)

---

## 🚀 How to Fix

### Step 1: Run the Migration in Supabase

1. Open your Supabase project dashboard: https://supabase.com/dashboard/project/mvvuegptxjykhzpatsmn
2. Go to **SQL Editor** (left sidebar)
3. Click **New Query**
4. Copy the **ENTIRE** content of `database_migrations/003_fix_grn_processing.sql`
5. Paste it and click **Run** (or press Ctrl+Enter)
6. You should see "Success. No rows returned" message

### Step 2: (Optional) Reset Test Data

If you want to clear all previous GRNs and start fresh for testing:

1. In SQL Editor, create another new query
2. Copy content from `database_migrations/reset_grn_test_data.sql`
3. Run it
4. This will:
   - Delete all existing GRNs
   - Reset all PO `received_quantity` to 0
   - Change completed POs back to "approved"

### Step 3: Test the Flow

1. Restart your dev server (stop and `npm run dev`)
2. Go to **GRN Page** → **Create GRN**
3. Open the "From Purchase Order" dropdown
4. You should see:
   - ✅ Only POs that have items left to receive
   - ❌ No POs that have been fully received

5. Create a GRN for one PO
6. Refresh the page
7. That PO should now:
   - Disappear from dropdown (if fully received), OR
   - Show reduced "Ordered" vs "Already Received" quantities

---

## 📊 How It Works Now

```
PO Created (500 Basmati Rice)
   ↓
Status: "approved"
received_quantity: 0
   ↓
[Shows in GRN dropdown] ✅
   ↓
Create GRN (receive 300)
   ↓
RPC updates:
  - received_quantity: 300
  - open_quantity: 200
   ↓
[Still shows in dropdown - 200 remaining] ✅
   ↓
Create 2nd GRN (receive 200)
   ↓
RPC updates:
  - received_quantity: 500
  - open_quantity: 0
  - PO status → "completed"
   ↓
[Removed from dropdown] ✅
```

---

## Verification Query

After migration, run this in SQL Editor to verify:

```sql
SELECT
    po.doc_number,
    po.status,
    pol.line_num,
    i.item_name,
    pol.quantity as ordered,
    COALESCE(pol.received_quantity, 0) as received,
    (pol.quantity - COALESCE(pol.received_quantity, 0)) as remaining,
    CASE
        WHEN COALESCE(pol.received_quantity, 0) >= pol.quantity
        THEN '❌ Fully Received (Hidden)'
        ELSE '✅ Available in Dropdown'
    END as dropdown_status
FROM purchase_orders po
JOIN po_lines pol ON pol.po_id = po.id
LEFT JOIN items i ON i.id = pol.item_id
ORDER BY po.doc_number, pol.line_num;
```

This will show you which POs should appear in the dropdown.

---

## Need Help?

If the migration fails, check:

1. ✅ You're logged into the correct Supabase project
2. ✅ You have `Owner` or `Admin` role
3. ✅ Copy-paste the ENTIRE SQL file (scroll to bottom)

If POs still show incorrectly:

- Run the reset script
- Hard refresh browser (Ctrl+Shift+R)
- Check browser console for errors
