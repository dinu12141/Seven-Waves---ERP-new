import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from 'src/boot/supabase'

export const useEmployeeStore = defineStore('employee', () => {
  // ============================================
  // STATE
  // ============================================

  const employees = ref([])
  const currentEmployee = ref(null)

  // Hierarchy
  const salesHierarchy = ref([])
  const flattenedHierarchy = ref([])

  // Configuration References
  const salaryComponents = ref([])
  const commissionPackages = ref([])
  const accountHeads = ref([]) // For bank selection if needed
  const departments = ref([])
  const designations = ref([])

  // UI State
  const loading = ref(false)
  const error = ref(null)

  // ============================================
  // GETTERS
  // ============================================

  const zones = computed(() => salesHierarchy.value.filter((h) => h.type === 'Zone'))
  const activeCommissionPackages = computed(() =>
    commissionPackages.value.filter((p) => p.is_active),
  )

  // ============================================
  // ACTIONS - CORE EMPLOYEE
  // ============================================

  async function fetchEmployees() {
    try {
      loading.value = true
      const { data, error: fetchError } = await supabase
        .from('employees')
        .select('*')
        .order('created_at', { ascending: false })

      if (fetchError) throw fetchError
      employees.value = data
      return { success: true, data }
    } catch (err) {
      console.error('Error fetching employees:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function generateUserCode() {
    try {
      const year = new Date().getFullYear()

      // Fetch the latest employee code
      const { data, error: fetchError } = await supabase
        .from('employees')
        .select('employee_code')
        .order('created_at', { ascending: false })
        .limit(1)
        .single()

      if (fetchError && fetchError.code !== 'PGRST116') {
        // PGRST116 means no rows found
        throw fetchError
      }

      let sequence = '0001'

      if (data && data.employee_code) {
        // Expected format: EMP-{YYYY}-{SEQ}
        const parts = data.employee_code.split('-')
        if (parts.length === 3) {
          const lastSeq = parseInt(parts[2], 10)
          if (!isNaN(lastSeq)) {
            sequence = String(lastSeq + 1).padStart(4, '0')
          }
        }
      }

      return `EMP-${year}-${sequence}`
    } catch (err) {
      console.error('Error generating user code:', err)
      // Fallback to timestamp to ensure *something* is generated
      return `EMP-${Date.now().toString().slice(-6)}`
    }
  }

  // ============================================
  // ACTIONS - HIERARCHY
  // ============================================

  async function fetchHierarchy() {
    try {
      const { data, error: fetchError } = await supabase
        .from('sales_hierarchy')
        .select('*')
        .eq('is_active', true)
        .order('name')

      if (fetchError) throw fetchError

      // Store raw for filtering
      salesHierarchy.value = data

      return { success: true, data }
    } catch (err) {
      console.error('Error fetching hierarchy:', err)
      return { success: false, error: err.message }
    }
  }

  function getChildren(parentId) {
    return salesHierarchy.value.filter((h) => h.parent_id === parentId)
  }

  // ============================================
  // ACTIONS - CONFIGURATION
  // ============================================

  async function fetchConfigurationData() {
    try {
      loading.value = true

      const results = await Promise.all([
        fetchHierarchy(),
        supabase.from('commission_packages').select('*').eq('is_active', true),
        supabase.from('departments').select('*').order('name'),
        supabase.from('designations').select('*').order('name'),
      ])

      const packagesRes = results[1]

      if (packagesRes.error) throw packagesRes.error

      commissionPackages.value = packagesRes.data
      departments.value = results[2].data
      designations.value = results[3].data

      return { success: true }
    } catch (err) {
      console.error('Error fetching config:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // ============================================
  // ACTIONS - REGISTRATION (TRANSACTIONAL)
  // ============================================

  async function registerEmployee(payload) {
    // Payload structure:
    // {
    //   basic: { ... },
    //   status: { ... },
    //   banking: { ... },
    //   hierarchy: { ... },
    //   payment: { ... }
    // }

    try {
      loading.value = true
      const { basic, status, banking, hierarchy, payment } = payload

      // Helper to clean dates
      const cleanDate = (d) => (d && d !== '' ? d : null)
      const cleanId = (id) => (id && id !== '' ? id : null)

      // 1. Create Employee Record
      const employeeData = {
        employee_code: basic.code,
        first_name: basic.firstName,
        last_name: basic.lastName,
        name_with_initials: basic.initials,
        gender: basic.gender,
        nationality: basic.nationality,
        civil_status: basic.civilStatus,
        date_of_birth: cleanDate(basic.dob),
        nic_number: basic.nic,
        passport_number: basic.passport,
        driving_license: basic.license,

        personal_email: basic.email,
        mobile_phone: basic.mobile,
        permanent_address: basic.address,

        employment_type: status.type,
        date_of_joining: cleanDate(status.joiningDate),
        date_of_confirmation: cleanDate(status.confirmationDate),
        designation_id: cleanId(basic.designationId),
        department_id: cleanId(basic.departmentId),

        epf_number: status.epfNumber,
        etf_number: status.etfNumber,
        welfare_activation: status.welfare || false,

        salary_mode: banking.method, // Bank, Cash
        bank_name: banking.bankName,
        bank_branch: banking.branch,
        bank_account_no: banking.accountNumber, // Mapped to DB column

        education_qualifications: basic.education,
        kyc_documents: status.kycDocs,

        status: 'Active',
      }

      const { data: emp, error: createError } = await supabase
        .from('employees')
        .insert(employeeData)
        .select()
        .single()

      if (createError) throw createError

      const employeeId = emp.id

      // 2. Link Sales Hierarchy
      if (hierarchy.nodeId) {
        const { error: hierError } = await supabase.from('employee_sales_hierarchy').insert({
          employee_id: employeeId,
          hierarchy_id: hierarchy.nodeId,
          role: hierarchy.role, // Member, Leader
        })

        if (hierError) console.error('Hierarchy link error (non-fatal):', hierError)
      }

      // 3. Create Salary Configuration
      const salaryConfig = {
        employee_id: employeeId,
        method: payment.method, // Basic, Unit, Day, Commission
        basic_salary: payment.basicSalary || 0,
        unit_rate: payment.unitRate || 0,
        daily_rate: payment.dailyRate || 0,
        commission_package_id: payment.packageId,
        allowances: payment.allowances || [],
      }

      const { error: salaryError } = await supabase
        .from('salary_configurations')
        .insert(salaryConfig)

      if (salaryError) console.error('Salary config error (non-fatal):', salaryError)

      // Refresh list
      await fetchEmployees()

      return { success: true, data: emp }
    } catch (err) {
      console.error('Registration Error:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  return {
    employees,
    currentEmployee,
    salesHierarchy,
    commissionPackages,
    loading,
    error,

    fetchEmployees,
    generateUserCode,
    fetchHierarchy,
    getChildren,
    fetchConfigurationData,
    registerEmployee,
    zones,
    activeCommissionPackages,
    salaryComponents,
    accountHeads,
    departments,
    designations,
    flattenedHierarchy,
  }
})
