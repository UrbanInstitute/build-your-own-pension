###
    Cost Calculation for FAS
    Ben Southgate (bsouthga@gmail.com)
    12/11/14
###

module.exports = class FASCost

  constructor : (weights) ->
    @update(weights)

  calc : (plan) ->

    base_start_age = plan.parameters.start_age
    cost = 0
    weight_sum = 0

    weights = @weights

    for age in @start_ages
      plan_cost = plan.set('start_age', parseFloat(age)).variables.cost
      w = weights[age]
      for a of plan_cost
        wgt = if a of w then w[a] else 0
        weight_sum += wgt
        weighted_cost = plan_cost[a]*wgt
        cost += weighted_cost
    cost /= weight_sum
    plan.set('start_age', base_start_age, true)

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
