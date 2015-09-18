###
    Reusable Accrual Equation Generator
    Ben Southgate (bsouthga@gmail.com)
    12/11/14
###

Equation = require './Equation.coffee'

module.exports = class Deflated extends Equation

  constructor : (opts) ->

    defl_age = opts.deflation_age

    formula = if defl_age is undefined
                (p) ->
                  variable = @variables[opts.variable]
                  s = p.start_age
                  e = p.max_ret_age
                  inflation = 1 + p.inflation
                  inflation_reduction = 1
                  out = {}
                  for a in [s..e]
                    out[a] = variable[a] / inflation_reduction
                    inflation_reduction *= inflation
                  return out
              else
                (p) ->
                  variable = @variables[opts.variable]
                  s = p.start_age
                  e = p.max_ret_age
                  inflation = 1 + p.inflation
                  out = {}
                  for a in [s..e]
                    out[a] = variable[a] / inflation**(defl_age - s)
                  return out

    super
      name : opts.name
      parameters : [
        "start_age", "max_ret_age", "inflation"
      ]
      formula : formula
