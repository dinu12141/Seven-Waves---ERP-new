import { ref } from 'vue'
import { utils, writeFile } from 'xlsx'
import { jsPDF } from 'jspdf'
import autoTable from 'jspdf-autotable'
import { useAuthStore } from 'src/stores/authStore'

export function useExport() {
  const isExporting = ref(false)
  const authStore = useAuthStore()

  /**
   * Export data to Excel with SAP-style headers
   */
  const exportToExcel = (data, columns, reportName = 'Export', filename = 'export') => {
    try {
      isExporting.value = true

      const mappedData = data.map((row) => {
        const newRow = {}
        columns.forEach((col) => {
          let val = row[col.field]
          if (typeof col.field === 'function') {
            val = col.field(row)
          }
          if (col.format && typeof col.format === 'function') {
            val = col.format(val, row)
          }
          newRow[col.label] = val
        })
        return newRow
      })

      // Create worksheet
      const ws = utils.json_to_sheet([])

      // Add SAP Headers
      utils.sheet_add_aoa(
        ws,
        [
          ['Seven Waves ERP'],
          [reportName],
          [`Generated on: ${new Date().toLocaleString()}`],
          [], // Empty row
        ],
        { origin: 'A1' },
      )

      // Add actual data starting from row 5
      utils.sheet_add_json(ws, mappedData, { origin: 'A5', skipHeader: false })

      // Auto-adjust column widths
      const colWidths = columns.map((col) => {
        let maxLength = col.label.length
        mappedData.forEach((row) => {
          const val = row[col.label] ? String(row[col.label]) : ''
          if (val.length > maxLength) maxLength = val.length
        })
        return { wch: maxLength + 2 }
      })
      ws['!cols'] = colWidths

      const wb = utils.book_new()
      utils.book_append_sheet(wb, ws, 'Report')
      writeFile(wb, `${filename}.xlsx`)
    } catch (error) {
      console.error('Export to Excel failed:', error)
      throw error
    } finally {
      isExporting.value = false
    }
  }

  /**
   * Export data to PDF with SAP Business One HANA layout
   */
  const exportToPDF = (data, columns, title, filename = 'report') => {
    try {
      isExporting.value = true
      const doc = new jsPDF({
        orientation: 'landscape', // landscape is better for dense reports
        unit: 'mm',
        format: 'a4',
      })

      // --- Header ---
      doc.setFontSize(16)
      doc.setTextColor(40)
      doc.text('Seven Waves ERP - Inventory Department', 14, 15)

      doc.setFontSize(10)
      doc.setTextColor(100)
      doc.text(`Report: ${title}`, 14, 22)

      const user = authStore.user?.email || authStore.profile?.full_name || 'System User'
      doc.text(`Generated Date/Time: ${new Date().toLocaleString()}`, 14, 27)
      doc.text(`User ID: ${user}`, 14, 32)

      // --- Table ---
      const tableColumn = columns.map((col) => col.label)
      const tableRows = []

      data.forEach((row) => {
        const rowData = []
        columns.forEach((col) => {
          let val = row[col.field]
          if (typeof col.field === 'function') {
            val = col.field(row)
          }
          if (col.format && typeof col.format === 'function') {
            val = col.format(val, row)
          }
          if (val === null || val === undefined) val = ''
          rowData.push(val)
        })
        tableRows.push(rowData)
      })

      autoTable(doc, {
        head: [tableColumn],
        body: tableRows,
        startY: 38,
        theme: 'grid',
        styles: {
          fontSize: 10, // SAP standard for print is dense
          cellPadding: 1.5,
          overflow: 'linebreak',
          valign: 'middle',
          lineWidth: 0.1,
          lineColor: [200, 200, 200],
        },
        headStyles: {
          fillColor: [41, 128, 185], // SAP Blue
          textColor: 255,
          fontSize: 10,
          fontStyle: 'bold',
          halign: 'center',
        },
        alternateRowStyles: {
          fillColor: [248, 249, 250],
        },
        margin: { top: 38 },
        didDrawPage: function (data) {
          // Footer
          const str = 'Page ' + doc.internal.getNumberOfPages()
          doc.setFontSize(10)
          const pageSize = doc.internal.pageSize
          const pageHeight = pageSize.height ? pageSize.height : pageSize.getHeight()
          doc.text(str, data.settings.margin.left, pageHeight - 10)
        },
      })

      doc.save(`${filename}.pdf`)
    } catch (error) {
      console.error('Export to PDF failed:', error)
      throw error
    } finally {
      isExporting.value = false
    }
  }

  return {
    isExporting,
    exportToExcel,
    exportToPDF,
  }
}
