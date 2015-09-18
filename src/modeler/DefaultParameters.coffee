###
  Default Parameters
  Ben Southgate (bsouthga@gmail.com)
  12/05/14
###

module.exports = class DefaultParameters

  constructor : (data, merit) ->
    # ----------------------------------------
    #
    # Baseline Plan parameters
    #
    # ----------------------------------------
    @defaults =
      # plan type indicator
      _PLAN_TYPE                    : "FAS"
      # Include social security results----
      calculate_social_security     : true
      # starting year of simulation
      start_year                    : 2014
      # Starting age -----------------------
      start_age                     : 25
      # Starting Salary --------------------
      start_salary                  : 44411
      # Maximum Allowed Retirement Age -----
      max_ret_age                   : 75
      # Minimum Years for Vesting ----------
      vest_years                    : 5
      # Market Rate of Return --------------
      ror                           : 0.05
      # Market return stdev (CB only) ------
      ror_sigma                     : 0.08
      # Discount rate for employee ---------
      discount                      : 0.05
      # Discount rate for employee ---------
      cash_out                      : 0.03
      # Cost of Living Adjustment ----------
      cola                          : 0.03
      # Years used in fas calculation ------
      fas_years                     : 3
      # Wage growth independent of inflation
      wage_growth                   : 0.00
      # CPI assumption ---------------------
      inflation                     : 0.03
      # Employee contribution rate ---------
      employee_contrib_rate         : 0.06
      # additional FAS growth --------------
      additional_fas_growth         : 0

      #------- CB Specific params ----------

      # Employer contribution rate ---------
      employer_contrib_rate         : 0.04
      # guarantee_enabled
      guarantee_enabled             : true
      # guarantee rate
      guarantee                     : 0.03
      # cap_enabled
      cap_enabled                   : true
      # cap rate
      cap                           : 0.05

      #------- End CB Specific params ------

      # Multiplier before additions --------
      base_mutiplier                : 0.02
      # Additon to multiplier from YOS / retage
      multiplier_bonus              : 0
      # Normal Retirement Age --------------
      NRA                           : 62
      # Early Retirement Age ---------------
      ERA                           : 55
      # Penalty (% of benefit) for early retirement
      early_reduction_factor        : 0.05
      ### objects for salary growth and mortality ###
      merit_level : "med"
      sal_growth : merit
      survival : (1 - data.mortality[a] for a in [0..120])
      ### Eligibility function ###
      eligible : (p, quit_age) ->
        yos = quit_age - p.start_age
        eligible_age = p.ERA
        return Math.max(eligible_age, quit_age)
      ### early retirement function ###
      early_reduction : (p, takeupage) ->
        p.early_reduction_factor*(
          Math.max(0, p.NRA - takeupage)
        )
      ### early retirement function ###
      multiplier : (p, takeupage) ->
        p.base_mutiplier + p.multiplier_bonus*(
          Math.max(0, takeupage - p.NRA)
        )
