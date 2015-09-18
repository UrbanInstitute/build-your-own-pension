###
    Basic Cash Balance Pension Model Class
    Ben Southgate (bsouthga@gmail.com)
    12/3/14
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


module.exports = class CashBalance extends Model

  constructor : (opts) ->

    # reference for costly functions
    pow = Math.pow
    max = Math.max

    get_bounded_ror = (p) ->
      ror = p.ror
      guarantee = p.guarantee
      cap = p.cap
      # bound rate of return using cap and guarantee
      bounded_ror = ror
      if p.guarantee_enabled
        bounded_ror = max(guarantee, bounded_ror)
      if p.cap_enabled
        bounded_ror = Math.min(cap, bounded_ror)
      return bounded_ror

    ###
      -------------------------------------
      Yearly employee contributions
      -------------------------------------
    ###
    EQ_contributions = new Contributions
      name : "contributions"
      rate : "employee_contrib_rate"

    ###
      -------------------------------------
      Yearly employer contributions
      -------------------------------------
    ###
    EQ_govContrib = new Contributions
      name : "govContrib"
      rate : "employer_contrib_rate"

    ###
      -------------------------------------
      Opportunity cost balance
      -------------------------------------
    ###
    EQ_opportunity_cost = new Account
      name : "opportunity_cost"
      variable : "contributions"
      ror : "discount"

    ###
      -------------------------------------
      Yearly employee contributions (government perpsetive)
      -------------------------------------
    ###
    EQ_employee_contrib_gov_balance = new Account
      name : "employee_contrib_gov_balance"
      variable : "contributions"
      ror : "ror"

    ###
      -------------------------------------
      Yearly employee contributions
      -------------------------------------
    ###
    EQ_cash_out_balance = new Account
      name : "cash_out_balance"
      variable : "contributions"
      ror : "cash_out"

    ###
      -------------------------------------
      Yearly employer contributions
      -------------------------------------
    ###
    EQ_nominal_wealth = new Equation
      name : "nominal_wealth"
      parameters : [
        "start_age", "max_ret_age", "refund_ror",
        "cap_enabled", "guarantee_enabled", "cap", "guarantee"
      ]
      formula : (p) ->
        ### Extract current variable values from model ###
        contributions = @variables.contributions
        govContrib = @variables.govContrib
        cashout = @variables.cash_out_balance

        ### Extract current parameters from model ###
        start = p.start_age
        end = p.max_ret_age
        bounded_ror = 1 + get_bounded_ror(p)
        cash_out_ror = p.cash_out + 1
        vest_years = p.vest_years
        temp = {}
        out = {}
        emp_contrib = {}
        temp[start] = out[start] = emp_contrib[start] = 0

        for age in [start+1..end] by 1
          increase = contributions[age] + govContrib[age]
          temp[age] = (increase + temp[age-1])*(bounded_ror)
          out[age] =  if (age - start) > vest_years
                        temp[age]
                      else
                        cashout[age]
        return out

    ###
      -------------------------------------
      Yearly employer contributions
      -------------------------------------
    ###
    EQ_grown_account = new Equation
      name : "grown_account"
      parameters : [
        "start_age", "max_ret_age", "refund_ror",
        "cap_enabled", "guarantee_enabled", "cap", "guarantee"
      ]
      formula : (p) ->
        ### Extract current variable values from model ###
        nominal_wealth = @variables.nominal_wealth
        start = p.start_age
        end = p.max_ret_age
        bounded_ror = 1 + get_bounded_ror(p)
        out = {}
        for quit_age in [start..end] by 1
          takeup = max(65, quit_age)
          inc = pow(bounded_ror, takeup - quit_age)
          out[quit_age] = nominal_wealth[quit_age]*inc
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
        "cap", "cap_enabled"
      ]
      formula : (p) ->
        ### Extract current variable values from model ###
        gov_rate = @variables.gov_equiv_rate
        salaries = @variables.salaries
        start = p.start_age
        end = p.max_ret_age
        ror = p.ror + 1

        mu = p.ror
        sigma = p.ror_sigma
        cap = p.cap
        guarantee = p.guarantee
        gov_cntrb = p.employer_contrib_rate
        emp_cntrb = p.employee_contrib_rate
        ctrb = (gov_cntrb + emp_cntrb)

        # Calculate expectation
        E_ror = if sigma != 0
                  bgs.exp_bounded_ror(mu, sigma, guarantee, cap)
                else
                  Math.max(guarantee, Math.min(cap, mu))

        ### evaluate variable formula ###
        balance = {}
        topup = {}
        cost = {}
        out = {}

        balance[start] = ctrb*salaries[start]
        out[start] = topup[start] = 0

        for age in [start+1..end] by 1
          yos = (age - start)

          b_last = balance[age-1]

          topup[age] = b_last*(E_ror - mu)

          balance[age] = (
            b_last*(1 + E_ror) +
            ctrb*salaries[age] +
            topup[age]
          )

          period_cost = (gov_cntrb*salaries[age] + topup[age])

          out[age] = out[age-1]*ror + period_cost

        return out




    ###
      ----------------------------------
      equivalent gov rate
      ----------------------------------
    ###
    EQ_gov_equiv_rate = new Equation
      name : "gov_equiv_rate"
      parameters : [
        "start_age", "max_ret_age", "discount", "survival"
      ]
      formula : (p) ->

        cost = @variables.cost
        salaries = @variables.salaries
        cashout = @variables.cash_out_balance
        gov_value = @variables.employee_contrib_gov_balance

        start = p.start_age
        end = p.max_ret_age
        ror = p.ror + 1
        vest_years = p.vest_years
        cr = p.employee_contrib_rate

        out = {}
        cntrb = {}
        guar = {}
        pv_salary = {}
        pv_salary[start] = salaries[start]

        out[start] = 0

        for age in [start+1..end] by 1

          yos = age - start

          pv_salary[age] = pv_salary[age-1]*ror + salaries[age]

          if yos > vest_years
            out[age] = cost[age] / pv_salary[age]
          else
            out[age] = (cashout[age] - gov_value[age]) / pv_salary[age]

        return out





    ###
      -------------------------------------
      Net Cash Balance Wealth
      -------------------------------------
    ###
    EQ_nominal_net_wealth = new Equation
      name : "nominal_net_wealth"
      parameters : [
        "start_age", "max_ret_age", "inflation", "refund_ror",
        "cap_enabled", "guarantee_enabled", "cap", "guarantee"
      ]
      formula : (p) ->
        ### Extract current variable values from model ###
        opp_cost = @variables.opportunity_cost
        nominal_wealth = @variables.nominal_wealth
        ### Extract current parameters from model ###
        start = p.start_age
        end = p.max_ret_age
        cap = p.cap
        ### subtract potential stock earnings from nominal_wealth ###
        temp = {}
        out = {}
        temp[start] = out[start] = 0
        for age in [start+1..end] by 1
          out[age] = (nominal_wealth[age] - opp_cost[age])
        return out

    ###
      -------------------------------------
      Cash Balance Wealth (deflated)
      -------------------------------------
    ###
    EQ_wealth = new Deflated
      name : "wealth"
      variable : "nominal_wealth"


    ###
      -------------------------------------
      Cash Balance Net Wealth (deflated)
      -------------------------------------
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
      "name" : "accrual"
      "variable" : "nominal_wealth"
      "exclude_surv" : true


    ###
      ----------------------------------
      wealth accrual (net)
      ----------------------------------
    ###
    EQ_net_accrual = new Accrual
      "name" : "net_accrual"
      "variable" : "nominal_net_wealth"
      "exclude_surv" : true

    ###
      -----------------------------------------------
        Annuity ratio
      -----------------------------------------------
    ###
    EQ_ratios = new Equation
      name : "ratios"
      parameters : [
        "start_age", "max_ret_age", "discount", "survival", "cola"
      ]
      formula : (p) ->
        ### Extract current parameters from model ###
        start = p.start_age
        end = p.max_ret_age
        surv = p.survival
        disc = 1 + p.discount
        cola = 1 + p.cola
        inflation = 1 + p.inflation
        bounded_ror = 1 + get_bounded_ror(p)
        ### evaluate variable formula ###
        out = {}
        # declare inner vars out here
        ratio = 0
        p_surv = 1
        c = 1
        d = 1
        # calculate annuity ratio
        for quit_age in [start..end] by 1
          t = takeup = max(quit_age, 65)
          ratio = 0
          p_surv = 1
          c = 1
          d = 1
          while (++t < 120)
            ratio += p_surv * (c *= cola) / (d *= disc)
            p_surv = 0 if ((p_surv *= surv[t]) < 0)
          out[quit_age] = ratio
        return out


    ###
      --------------------------------------
      nominal benefit (annuitized wealth)
      --------------------------------------
    ###
    EQ_nominal_benefit = new Equation
      name : "nominal_benefit"
      parameters : [
        "start_age", "max_ret_age", "discount", "survival", "cola"
      ]
      formula : (p) ->
        ### Extract current variable values from model ###
        nominal_wealth = @variables.nominal_wealth
        ratios = @variables.ratios
        ### Extract current parameters from model ###
        start = p.start_age
        end = p.max_ret_age
        surv = p.survival
        disc = 1 + p.discount
        cola = 1 + p.cola
        inflation = 1 + p.inflation
        bounded_ror = 1 + get_bounded_ror(p)
        ### evaluate variable formula ###
        out = {}
        # declare inner vars out here
        ratio = 0
        p_surv = 1
        c = 1
        d = 1
        # calculate annuity ratio
        for quit_age in [start..end] by 1
          t = takeup = max(quit_age, 65)
          ratio = ratios[quit_age]
          if ratio
            # grow account with bounded return to 65
            grown = nominal_wealth[quit_age] * pow(bounded_ror, takeup - quit_age)
            annuity_at_takeup = (grown / ratio)
            out[quit_age] = annuity_at_takeup
          else
            out[quit_age] = 0
        return out


    ###
      --------------------------------------
      benefit (annuitized wealth)
      --------------------------------------
    ###
    EQ_benefit = new Deflated
      name : "benefit"
      variable : "nominal_benefit"


    ###
      --------------------------------------
      benefit (annuitized wealth)
      --------------------------------------
    ###
    EQ_benefit75 = new Equation
      name : "benefit75"
      parameters : [
        "start_age", "max_ret_age", "discount",
        "survival", "cola"
      ]
      formula : (p) ->
        ### Extract current variable values from model ###
        nominal_wealth = @variables.nominal_wealth
        ### Extract current parameters from model ###
        start = p.start_age
        end = p.max_ret_age
        surv = p.survival
        disc = 1 + p.discount
        cola = 1 + p.cola
        inflation = 1 + p.inflation
        bounded_ror = 1 + get_bounded_ror(p)
        ### evaluate variable formula ###
        out = {}
        # declare inner vars out here
        ratio = 0
        p_surv = 1
        c = 1
        d = 1
        # calculate annuity ratio
        for quit_age in [start..end] by 1
          q = takeup = max(quit_age, 65) # minimum annuity age = 65
          ratio = 0
          p_surv = 1
          c = 1
          d = 1
          # loop from quit age to 120
          while (++q < 120)
            # add up the survival rate * (cola / discount)
            ratio += p_surv * (c *= cola) / (d *= disc)
            p_surv = 0 if ((p_surv *= surv[q]) < 0)
          if ratio
            grown = nominal_wealth[quit_age] * pow(bounded_ror, max(0, takeup - quit_age))
            annuity_at_takeup = (grown / ratio) * pow(cola, max(75-takeup, 0))
            out[quit_age] = annuity_at_takeup / pow(inflation, 75-start)
          else
            out[quit_age] = 0
        return out



    ###
      ----------------------------------
      Replacement Rate
      ----------------------------------
    ###
    EQ_replacement = new Equation
      name : "replacement"
      parameters : [
        "start_age", "max_ret_age", "discount", "survival", "inflation"
      ]
      formula : (p) ->
        ### Extract current variable values from model ###
        ben75 = @variables.benefit75
        sal = @variables.salaries
        ss = @variables.social_security
        ### Extract current parameters from model ###
        start = p.start_age
        end = p.max_ret_age
        inflation = p.inflation
        ### evaluate variable formula ###
        out = {}
        sal_inv = 1 / sal["60"]
        for a in [start..end] by 1
          out[a] = (ben75[a]*pow(1 + inflation, 60-start) + ss[a]) * sal_inv
        return out



    ### full list of FAS equations ###
    full_equations = [
      new Salaries()
      new SocialSecurity()
      EQ_ratios
      EQ_contributions
      EQ_cash_out_balance
      EQ_employee_contrib_gov_balance
      EQ_opportunity_cost
      EQ_govContrib
      EQ_nominal_wealth
      EQ_nominal_net_wealth
      EQ_grown_account
      EQ_cost
      EQ_gov_equiv_rate
      EQ_wealth
      EQ_net_wealth
      EQ_accrual
      EQ_net_accrual
      EQ_nominal_benefit
      EQ_benefit
      EQ_benefit75
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
