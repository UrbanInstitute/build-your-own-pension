###
    Reusable Account Balance
    Ben Southgate (bsouthga@gmail.com)
    12/11/14
###

Equation = require './Equation.coffee'

module.exports = class Account extends Equation

  constructor : (opts) ->
    variable = opts.variable
    ror = opts.ror

    formula = (p) ->
      ### Extract current variable values from model ###
      vector = @variables[variable]
      ### Extract current parameters from model ###
      start = p.start_age
      end = p.max_ret_age
      ror_val = p[ror] + 1
      temp = {}
      out = {}
      temp[start] = out[start] = 0
      for age in [start+1..end] by 1
        temp[age] = (vector[age] + temp[age-1])*(ror_val)
        out[age] = temp[age]
      return out

    super
      name : opts.name
      parameters : [
        "start_age", "max_ret_age", ror
      ]
      formula : formula
