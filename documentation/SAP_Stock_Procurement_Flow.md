# SAP Business One HANA - ERP Process Flows

This document outlines the core functional logic and process flows implemented in **Seven Waves ERP**, complying with **SAP Business One HANA** standards.

---

## 1. Inventory Management Logic

The core of the system is the **Item Master Data** and the real-time stock calculation logic.

### 1.1. Item Types

Every item belongs to one or more of the following categories (Logic implemented in `ItemMasterData`):

- **Inventory Item**: Physical goods tracked in the warehouse. (Updates `warehouse_stock`).
- **Sales Item**: Items that can be sold to customers (Appears in POS/Sales Orders).
- **Purchase Item**: Items bought from suppliers (Appears in POs).

### 1.2. Stock Availability Formula (SAP Standard)

The system calculates stock availability in real-time using the following standard SAP HANA formula:

$$ \text{Available} = \text{In Stock} + \text{Ordered} - \text{Committed} $$

| Term          | Definition                                            | Source Document                                                  |
| :------------ | :---------------------------------------------------- | :--------------------------------------------------------------- |
| **In Stock**  | Physical quantity currently in the warehouse.         | Increased by **GRN**, Decreased by **Delivery/Invoice**.         |
| **Ordered**   | Quantity ordered from suppliers but not yet received. | Increased by **Purchase Order (PO)**.                            |
| **Committed** | Quantity ordered by customers but not yet delivered.  | Increased by **Sales Order**, Decreased by **Kitchen/Delivery**. |

**Logic Implementation:**

- If `Available Stock` < `Min Stock Level`, the system triggers an **Inventory Alert**.

---

## 2. Procurement Process (Purchase to Pay)

This flow manages how goods are requested, ordered, and received.

### Flow Overview

1.  **Requirement** (Manual or System Alert)
2.  **Purchase Request (PR)**
3.  **Purchase Order (PO)**
4.  **Goods Receipt PO (GRN)**

### 2.1. Purchase Request (PR) `[OPRQ]`

- **Trigger**:
  - **Manual**: Staff creates a request for items.
  - **Automatic**: System runs `checkStockAlerts()` logic. If an item falls below `Min Stock`, a PR is suggested/created in the Procurement Dashboard.
- **Status**: `Open` -> `Ordering` -> `Closed`.

### 2.2. Purchase Order (PO) `[OPOR]`

The official contract sent to the supplier.

- **Creation**: Can be created manually or converted from a **PR** (`createPOFromPR`).
- **Stock Impact**:
  - **Increases `Ordered` Qty** immediately upon creation (via Database Trigger `trg_po_stock_ordered`).
  - Does **NOT** affect `In Stock` yet.
- **Linkage**: Stores `base_entry` (PR ID) to maintain the audit trail.

### 2.3. Goods Receipt PO (GRN) `[OIGN]`

The recording of goods physically entering the warehouse.

- **Creation**: Usually copied from a **PO**.
- **Stock Impact**:
  - **Increases `In Stock` Qty**.
  - **Decreases `Ordered` Qty** (reversing the PO impact).
  - Updates `Last Purchase Price` and `Moving Average Cost` (if valuation method is Moving Average).
- **Accounting (Backend)**:
  - Debit: Inventory Account
  - Credit: GRN Suspense Account (Allocation)

---

## 3. Sales Process (Order to Cash)

### 3.1. Sales Order

- **Effect**:
  - **Increases `Committed` Qty** in the warehouse.
  - Reduces `Available` stock (preventing the same item from being sold twice).

### 3.2. A/R Invoice & Delivery

- **Effect**:
  - **Decreases `In Stock` Qty**.
  - **Decreases `Committed` Qty** (clearing the reservation made by the Sales Order).
  - Records Revenue.

---

## 4. Inventory Valuation Methods

The system supports the following standard SAP valuation methods per item:

1.  **Moving Average Price (MAP)**:
    - Cost is recalculated after every **Goods Receipt**.
    - $$ \text{New Cost} = \frac{(\text{Old Qty} \times \text{Old Cost}) + (\text{New Qty} \times \text{Purchase Price})}{\text{Total Qty}} $$
2.  **Standard Price**: Fixed cost manually set for the item (common for semi-finished goods).
3.  **FIFO** (First-In, First-Out): Layers of cost are tracked per batch/receipt (Planned feature).

---

## 5. Warehouse & Bin Management

- **Warehouses**: Physical or logical locations (e.g., Main Store, Kitchen, Bar).
- **Default Warehouse**: Configured in Item Master.
- **Stock Transfers**: Moving items between warehouses (Inventory Transfer Request -> Inventory Transfer).
  - Moves stock from `Warehouse A` to `Warehouse B`.
  - Updates `In Stock` values for both warehouses instantly.

---

## 6. Automation Features (Triggers)

### Database Triggers (PostgreSQL)

The system uses backend logic to ensure data integrity:

- `trg_po_stock_ordered`: Watcher on `po_lines`. When a PO is added/edited, it syncs the `Ordered` field in `warehouse_stock`.
- `trg_check_min_stock`: Watcher on `warehouse_stock`. Checks if the new balance is below `MinStockLevel` and creates an entry in `inventory_alerts`.

---

**Document Version**: 1.0.0
**Author**: Antigravity (AI)
**Compliance**: SAP Business One 10.0 Logic
