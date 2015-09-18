###
    Reusable salary equation
    Ben Southgate (bsouthga@gmail.com)
    12/11/14
###

Equation = require './Equation.coffee'

module.exports = class Salaries extends Equation

  constructor : ->

    formula = (p) ->
      ### Get the vector of salaries for a given starting age and
      wage growth assumption until an ending age ###
      ### Extract current parameters from model ###
      if p.use_current_salaries and @variables.salaries
        return @variables.salaries

      start = p.start_age
      end = p.max_ret_age
      wg = p.wage_growth + p.inflation
      sal_growth = p.sal_growth[p.merit_level]

      out = {}
      ### if there is fixed starting salary, use it, otherwise
          use the starting salary from the provided object ###
      out[start] = p.start_salary ? p.start_salaries[start]

      ### for each age from startage to endage ###
      for age in [(start+1)..end] by 1
        ### calculate the salary as the start wage times the
        product of all salary growth rates + general wage growth
        from the start age to the current age ###
        gr = sal_growth[age-1-start]
        out[age] = out[age-1]*(1+wg+gr)

      return out

    super
      name : "salaries"
      parameters : [
        "start_age", "max_ret_age", "wage_growth", "inflation"
        "start_salaries", "sal_growth", "start_salary"
      ]
      formula : formula

