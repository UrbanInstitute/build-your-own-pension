###
  FAS Pension Model
  Ben Southgate (bsouthga@gmail.com)
  12/05/14
###

bgs             = require '../bgs.coffee'
Model           = require './Model.coffee'
Equation        = require './Equation.coffee'
Account         = require './Account.coffee'
Accrual         = require './Accrual.coffee'
Deflated        = require './Deflated.coffee'
Contributions   = require './Contributions.coffee'
Salaries        = require './Salaries.coffee'
SocialSecurity  = require './SocialSecurity.coffee'


module.exports = class FAS extends Model

  constructor : (opts) ->

    # reference for costly functions
    pow = Math.pow
    abs = Math.abs

    ###
      -----------------------------------
        Equation object helper functions
      -----------------------------------
    ###
    paramBuilder = @paramBuilder

    ###
      -----------------------------------------------
        Calculate the pension benefit for a given
        FAS, quitting age, and takeup age
      -----------------------------------------------
    ###
    ben_formula = (opts) ->
      p =           opts.p
      fas =         opts.fas
      quit_age =    opts.quit_age
      takeupage =   opts.takeupage
      multiplier =  opts.multiplier
      penalty =     1 - opts.penalty

      yos = quit_age - p.start_age
      vested = (p.vest_years <= yos)
      ###final formula###
      if vested then (multiplier*fas*yos*penalty) else 0

    ###
      Determine present discounted value of
      total pension wealth for a given takeup age and
      benefit value, deflated to the takeupage
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      This function comprises up to 50% of cpu
      time and needs to be as efficient as possible
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ###
    `function wealthPDV(start, disc, surv, quit_age,
                        takeupage, ben, cola, red) {
        var value = 0,
            p_surv = c = d = 1;
        // Build up survival probability to takeupage
        while (quit_age++ < takeupage) {
          p_surv *= surv[quit_age];
          d *= disc;
        }
        // Calculate sum of stream of future benefits
        while (++takeupage < 120) {
          value += ben * p_surv * (c *= cola) / (d *= disc);
          if ((p_surv *= surv[takeupage]) < 0) p_surv = 0;
        }
        return value;
    }`

    ###
      -------------------------------------
      Final Average Salary
      -------------------------------------
    ###
    EQ_FAS = new Equation
      name : "FAS"
      parameters : [
        "fas_years", "start_age", "max_ret_age"
      ]
      formula : (p) ->
        ### Extract current variable values from model ###
        salaries = @variables.salaries
        ### Extract current parameters from model ###
        fas_years = p.fas_years
        start = p.start_age
        end = p.max_ret_age
        ### evaluate variable formula ###
        out = {}
        out[start] = 0
        for age in [start+1..end] by 1
          total = 0
          for fage in [Math.max(start, age-fas_years)..age-1] by 1
            total += salaries[fage]
          out[age] = total / fas_years
        return out

    ###
      -------------------------------------
      Yearly contributions
      -------------------------------------
    ###
    EQ_contributions = new Contributions
      name : "contributions"
      rate : "employee_contrib_rate"



    ###
      -------------------------------------
      gov account balance
      -------------------------------------
    ###
    EQ_gov_account_balance = new Account
      name : "gov_account_balance"
      variable : "contributions"
      ror : "ror"

    ###
      -------------------------------------
      employee opportunity cost
      -------------------------------------
    ###
    EQ_opportunity_cost = new Account
      name : "opportunity_cost"
      variable : "contributions"
      ror : "discount"

    ###
      -------------------------------------
      cashout balance
      -------------------------------------
    ###
    EQ_cashout_balance = new Account
      name : "cashout_balance"
      variable : "contributions"
      ror : "cash_out"

    ###
      -------------------------------------
      -------------------------------------
      -------------------------------------
      Calculates takeupage, benefit and wealth_PDV
      -------------------------------------
      -------------------------------------
      -------------------------------------
    ###
    EQ_takeupage = new Equation
      name : "takeupage"
      parameters : [
        "start_age", "max_ret_age", "cola", "discount",
        "survival", "eligible", "early_reduction",
        "additional_fas_growth"
      ]
      formula : (p) ->
        ### -------------------------------------------
              This equation sets two other variables
              for performance reasons, wealth PDV and benefit
            ------------------------------------------- ###
        pdv = @variables.wealth_PDV = {}
        ben = @variables.nominal_benefit = {}

        ### Extract current variable values from model ###
        fas = @variables.FAS
        ### Extract current parameters from model ###
        start = p.start_age
        end = p.max_ret_age
        ror = p.ror
        NRA = p.NRA
        fixed_takeup = p.fixed_takeup
        eligible = paramBuilder(p.eligible)
        surv = p.survival
        disc = 1 + p.discount
        ### Convert numeric parameters to functions
            if neccesary ###
        mul = paramBuilder(p.multiplier)
        pen = paramBuilder(p.early_reduction)
        cola = 1 + p.cola
        red = paramBuilder(p.early_reduction)
        ben_growth = p.additional_fas_growth + 1
        ### evaluate variable formula ###
        out = {}
        for age in [start..end] by 1
          ### If given an takeupage, no need to maximize ###
          if fixed_takeup is undefined
            ### Choose takeupage which maximizes PDV ###
            max_pension_wealth = -Infinity
            max_takeup = -Infinity
            max_ben = -Infinity
            max_takeup_age = Math.max(NRA, age)
            # Individuals can collect between first eligibility
            # and the maximum of their NRA and their current age
            for takeupage in [eligible(p, age)..max_takeup_age] by 1
              ### inputs for pension benefit formula ###
              opts =
                p          : p
                fas        : fas[age]
                quit_age   : age
                takeupage  : takeupage
                multiplier : mul(p, takeupage)
                penalty    : pen(p, takeupage)
              ### Calculate present value of wealth ###
              b = ben_formula(opts)*ben_growth**(takeupage - age)
              w = wealthPDV(
                start, disc, surv, age, takeupage,
                b, cola, red
              )
              if w > max_pension_wealth
                max_pension_wealth = w
                max_takeup = takeupage
                max_ben = b
            ben[age] = max_ben
            out[age] = max_takeup
            pdv[age] = max_pension_wealth
          else
            ### calculate using given takeup ###
            opts =
              p          : p
              fas        : fas[age]
              quit_age   : age
              takeupage  : fixed_takeup
              multiplier : mul(p, fixed_takeup)
              penalty    : pen(p, fixed_takeup)
            ben[age] = ben_formula(opts)
            out[age] = fixed_takeup
            pdv[age] = wealthPDV(
                start, disc, surv, age, fixed_takeup,
                ben[age], cola, red
              )
        return out


    ###
      -------------------------------------
      Baseline Annual Benefit
      -------------------------------------
    ###
    EQ_benefit = new Deflated
      name : "benefit"
      variable : "nominal_benefit"



    ###
      -------------------------------------
      Annual Benefit at age 75
      -------------------------------------
    ###
    EQ_benefit75_nominal = new Equation
        name : "benefit75_nominal"
        parameters : [
          "start_age", "max_ret_age", "multiplier"
        ]
        formula : (p) ->
          ### Extract current variable values from model ###
          fas = @variables.FAS
          takeup = @variables.takeupage
          ben = @variables.nominal_benefit
          ### Extract current parameters from model ###
          start = p.start_age
          end = p.max_ret_age
          inflation = 1 + p.inflation
          ### Convert numeric parameters to functions
              if neccesary ###
          cola = p.cola
          ### evaluate variable formula ###
          out = {}
          inflation_reduction = pow(1+inflation, 75 - start)
          for age in [start..end] by 1
            takeupage = takeup[age]
            cola_increase = (1 + cola)**(75 - takeupage+1)
            benefit = ben[age]
            out[age] = benefit*cola_increase
          return out



    ###
      -------------------------------------
      Annual Benefit at age 75 (deflated)
      -------------------------------------
    ###
    EQ_benefit75 = new Deflated
      name : "benefit75"
      variable : "benefit75_nominal"
      deflation_age : 75

    ###
      ----------------------------------
      Maximum pdv wealth
      ----------------------------------
    ###
    EQ_nominal_wealth = new Equation
      name : "nominal_wealth"
      parameters : [
        "start_age", "max_ret_age", "cola", "discount",
        "survival", "eligible", "early_reduction"
      ]
      formula : (p) ->
        ### Extract current variable values from model ###
        takeupage = @variables.takeupage
        ben = @variables.nominal_benefit
        pdv = @variables.wealth_PDV
        account = @variables.cashout_balance
        ### Extract current parameters from model ###
        start = p.start_age
        end = p.max_ret_age
        surv = p.survival
        disc = 1 + p.discount
        ### Convert numeric parameters to functions
            if neccesary ###
        red = paramBuilder(p.early_reduction)
        cola = 1 + p.cola
        ### evaluate variable formula ###
        out = {}
        infl_red = 1
        for age in [start..end] by 1
          yos = age-start
          ### if the not vested, then recieve account ###
          out[age] =  if yos > p.vest_years
                        pdv[age]
                      else
                        account[age]
        return out



    ###
      ----------------------------------
      Variable : Replacement Rate
      ----------------------------------
    ###
    EQ_gov_equiv_rate = new Equation
      name : "gov_equiv_rate"
      parameters : [
        "start_age", "max_ret_age", "discount", "survival"
      ]
      formula : (p) ->
        account = @variables.gov_account_balance
        refund = @variables.cashout_balance
        salaries = @variables.salaries
        takeupage = @variables.takeupage
        ben = @variables.nominal_benefit
        employee_pdv = @variables.wealth_PDV
        start = p.start_age
        end = p.max_ret_age
        ror = 1 + p.ror
        disc = 1 + p.disc
        surv = p.survival
        ### Convert numeric parameters to functions
            if neccesary ###
        red = paramBuilder(p.early_reduction)
        cola = 1 + p.cola
        out = {}
        pv_salary = {}
        pv_salary[start] = salaries[start]
        out[start] = 0
        for age in [start+1..end] by 1
          yos = age-start
          pv_salary[age] = pv_salary[age-1]*ror + salaries[age]
          ### if the not vested, then recieve account ###
          nominal = if yos > p.vest_years
                      if ror != disc
                        # calculate PDV from government's perspective
                        wealthPDV(
                          start, ror, surv, age, takeupage[age],
                          ben[age], cola, red
                        )
                      else
                        employee_pdv[age]
                    else
                      refund[age]
          out[age] = (nominal - account[age]) / pv_salary[age]
        return out

    ###
      ----------------------------------------
      Individual cost to government
      ----------------------------------------
    ###
    EQ_cost = new Equation
      name : "cost"
      parameters : [
        "discount", "ror", "guarantee", "guarantee_enabled",
        "cap", "cap_bonus", "cap_enabled"
      ]
      formula : (p) ->
        ### Extract current variable values from model ###
        gov_rate = @variables.gov_equiv_rate
        salaries = @variables.salaries
        start = p.start_age
        end = p.max_ret_age
        ror = p.ror + 1
        ### evaluate variable formula ###
        out = {}
        out[start] = 0
        for age in [start+1..end] by 1
          yos = age - start
          out[age] = out[age-1] + (gov_rate[age]*salaries[age]) / ror**yos
        return out

    ###
      ----------------------------------
      Maximum pdv wealth net of contributions
      ----------------------------------
    ###
    EQ_nominal_net_wealth = new Equation({
      name : "nominal_net_wealth"
      parameters : [
        "start_age", "max_ret_age", "cola", "discount",
        "survival", "eligible", "early_reduction"
      ]
      formula : (p) ->
        ### Extract current variable values from model ###
        account = @variables.opportunity_cost
        nominal_wealth = @variables.nominal_wealth
        ### Extract current parameters from model ###
        s = p.start_age
        e = p.max_ret_age
        ### evaluate variable formula ###
        out = {}
        for a in [s..e] by 1
          out[a] = nominal_wealth[a] - account[a]
        return out
    })



    ###
      ----------------------------------
      Maximum pdv wealth
      ----------------------------------
    ###
    EQ_wealth = new Deflated
      name : "wealth"
      variable : "nominal_wealth"

    ###
      ----------------------------------
      Maximum pdv wealth
      ----------------------------------
    ###
    EQ_net_wealth = new Deflated
      name : "net_wealth"
      variable : "nominal_net_wealth"

    ###
      ----------------------------------
      wealth accrual
      ----------------------------------
    ###
    EQ_accrual = new Accrual
      name : "accrual"
      variable : "wealth"

    ###
      ----------------------------------
      wealth accrual (net)
      ----------------------------------
    ###
    EQ_net_accrual = new Accrual
      name : "net_accrual"
      variable : "net_wealth"

    ###
      ----------------------------------
      Variable : Replacement Rate
      ----------------------------------
    ###
    EQ_replacement = new Equation({
      name : "replacement"
      parameters : [
        "start_age", "max_ret_age", "discount", "survival"
      ]
      formula : (p) ->
        ### Extract current variable values from model ###
        ben75 = @variables.benefit75_nominal
        sal = @variables.salaries
        ss = @variables.social_security
        ### Extract current parameters from model ###
        start = p.start_age
        end = p.max_ret_age
        inflation = p.inflation + 1
        ### evaluate variable formula ###
        out = {}
        sal_inv = 1 / (sal["60"]*pow(inflation, 75 - 60))
        for a in [start..end] by 1
          out[a] = (ben75[a] + ss[a]) * sal_inv
        return out
    })


    ### full list of FAS equations ###
    full_equations = [
      new Salaries()
      new SocialSecurity()
      EQ_FAS
      EQ_contributions
      EQ_cashout_balance
      EQ_opportunity_cost
      EQ_gov_account_balance
      EQ_takeupage
      EQ_benefit
      EQ_benefit75_nominal
      EQ_benefit75
      EQ_nominal_wealth
      EQ_nominal_net_wealth
      EQ_gov_equiv_rate
      EQ_cost
      EQ_wealth
      EQ_net_wealth
      EQ_accrual
      EQ_net_accrual
      EQ_replacement
    ]

    ### add only equations not desired to be skipped ###
    opts.eq_skip ?= []
    out_equations = (
      eq for eq in full_equations when not (eq.name in opts.eq_skip)
    )
    opts.equations = out_equations.concat(opts.equations or [])

    ### Call Model Class constructor ###
    super(opts)

