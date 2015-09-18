###
    Cost Calculation for Cash Balance using
    distributed rates of return
    Ben Southgate (bsouthga@gmail.com)
    12/11/14
###


bgs = require '../bgs.coffee'


module.exports = class CBCost

  constructor : (weights) ->
    @update(weights)

  calc : (plan) ->
    self = @

    # get parameters
    mu = plan.parameters.ror
    sigma = plan.parameters.ror_sigma
    cap = plan.parameters.cap
    guarantee = plan.parameters.guarantee
    gov_cntrb = plan.parameters.employer_contrib_rate
    emp_cntrb = plan.parameters.employee_contrib_rate
    ctrb = (gov_cntrb + emp_cntrb)

    # local reference to weights
    wgt = @weights

    # initialize payroll to 0
    payroll = bgs.zeros(@max_yos)
    sal_sum = bgs.zeros(@max_yos)
    balance = bgs.zeros(@max_yos)
    topup =   bgs.zeros(@max_yos)

    # Calculate expectation
    E_ror = if sigma != 0
              bgs.exp_bounded_ror(mu, sigma, guarantee, cap)
            else
              Math.max(guarantee, Math.min(cap, mu))

    # set plan startage and run
    min_startage = d3.min(@start_ages, parseFloat)

    salaries = plan.set('start_age', min_startage)
                    .variables
                    .salaries

    yos_salaries = bgs.obj(
      [q - min_startage, s] for q, s of salaries
    )

    # accumulate weighted payroll
    for age in @start_ages
      for yos in [0..@max_yos]
        if yos <= @max_yos
          if yos of yos_salaries
            payroll[yos] += yos_salaries[yos]*(wgt[age][yos] ? 0)
        else
          break

    # iterate through years of service, and build up cost
    cost = 0
    for t in [0..@max_yos] by 1
      if t != 0
        b_last = balance[t-1]
        balance[t] = b_last*(1 + E_ror) + ctrb*payroll[t] + topup[t]
        topup[t] = b_last*(E_ror - mu)
      else
        topup[0] = 0
        balance[0] = ctrb*payroll[0]

      period_cost = (gov_cntrb*payroll[t] + topup[t]) / (1 + mu)**t
      cost += period_cost

    return cost

  update : (weights) ->
    # sum weights by year of service
    @weights = weights
    @max_yos = 0
    @start_ages = []
    for age of weights
      @start_ages.push(parseFloat(age))
      for year of weights[age]
        year = parseFloat(year)
        @max_yos = year if year > @max_yos
    return @
