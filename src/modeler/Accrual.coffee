###
    Reusable Accrual Equation Generator
    Ben Southgate (bsouthga@gmail.com)
    12/11/14
###

Equation = require './Equation.coffee'

module.exports = class Accrual extends Equation

  constructor : (opts) ->

    exclude_surv = opts.exclude_surv

    formula = (p) ->
        ### Extract current variable values from model ###
        variable = @variables[opts.variable]

        ### Extract current parameters from model ###
        start = p.start_age
        end = p.max_ret_age
        surv = p.survival
        disc = p.discount + 1
        inflation = p.inflation + 1

        ### evaluate variable formula ###
        out = {}
        out[start] = variable[start]
        for a in [start+1..end] by 1
          yos = a - start
          m = if not exclude_surv then (surv[a]/disc) else disc
          out[a] = (variable[a]*m - variable[a-1])/inflation**(yos - 1)
        return out

    super
      name : opts.name
      parameters : [
        "start_age", "max_ret_age",
        "discount", "survival"
      ]
      formula : formula

