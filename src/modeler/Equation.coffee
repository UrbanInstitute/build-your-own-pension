###
  Equations for pension models
  Ben Southgate (bsouthga@gmail.com)
  12/05/14
###

module.exports = class Equation

  constructor : (opts) ->
    @formula = opts.formula
    @parameters = opts.parameters
    @name = opts.name

  valid : (parameters) ->
    ### Check if the containing model has the parameters
    neccesary for this equation ###
    for param in @parameters
      if not param of parameters
        throw "Equation: #{@name} requires parameter #{param}"

  evaluate : (context) ->
    if not context.parameters
      throw "No parameters were given when evaluating function #{@name}"
    @formula.call(context, context.parameters)
