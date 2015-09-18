#
# Logic to for cost-per-employee chart
# Ben Southgate
# 10/10/14
#

module.exports = class PlanCost

  constructor : ->
    self = @

  update : (cost) ->
    # Update the bar chart with new cost data
    self = @
    neg = cost < 0
    color = "#1696d2"
    d3.select('#plan_cost').text(d3.format('$,')(Math.round(cost)))
      .style('color', color)
    @lag_data = [cost]
    return self
