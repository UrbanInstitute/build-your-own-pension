###
  SLEPP interactive model "document on load" calls
  Ben Southgate (bsouthga@gmail.com)
  08/08/14
###


# Interactive Feature Dependencies
bgs = require './bgs.coffee'
Grader = require './interactive/Grader.coffee'
PlanCost = require './interactive/PlanCost.coffee'
MiniLine = require './interactive/MiniLine.coffee'

# Modeling Dependencies
FAS = require './modeler/FAS.coffee'
FASCost = require './modeler/FASCost.coffee'
CBCost = require './modeler/CBCost.coffee'
CashBalance = require './modeler/CashBalance.coffee'
DefaultParameters = require './modeler/DefaultParameters.coffee'



# ----------------------------------------
#
# IE Check and Modal Opening
#
# ----------------------------------------
IE10 = (Function('/*@cc_on return document.documentMode===10@*/')())

if IE10
  $('#IE10-modal').modal('show')
  $('#loading-overlay').remove()


# ----------------------------------------
#
# Download necessary json and then call interface functions
#
# ----------------------------------------
onDataLoad = (readyFunction) ->

  dataReady = (data, criteria, weights) ->
    # Call the ready function using the data
    readyFunction(data, criteria, weights)

    done = ->
      $('#loading-overlay').remove();
      # Transition the interface to visible
      d3.select("#interface")
        .transition()
        .duration(400)
        .style('opacity', 1)

    setTimeout done, 300

  ### load necessary json and call dataReady Function ###
  q = queue()

  # data to queue before model created
  [
    "assumptionSeries.json"
    "grade_criteria.json"
    "info_text.json"
    "weights.json"
    "still_working.json"
  ]
  .forEach (f) -> q.defer d3.json, "json/#{f}"

  q.awaitAll (error, datalist) -> dataReady datalist

# ----------------------------------------
#
# Main on ready function call
#
# ----------------------------------------
onDataLoad (datalist) ->

  [data, criteria, info_text, weights, still_working] = datalist

  # ----------------------------------------
  #
  # Salary Assumption Plot
  #
  # ----------------------------------------

  salary_parameters = {
    #          A0    ,  k
    "low" :  [0.04625, 0.2 ]
    "med" :  [0.06625, 0.15]
    "high" : [0.09625, 0.1 ]
  }

  merit = {}
  for level, parameters of salary_parameters
    merit[level] = {}
    [A0, k] = parameters
    for yos in [0..60]
      merit[level][yos] = A0*Math.E**(-k*yos)

  merit_series = ([parseFloat(y),v] for y, v of merit['med'])

  merit_plot = new MiniLine
    series : merit_series
    renderTo : "#merit-plot"
    title : "Annual Merit Increase"

  cost_calc = new PlanCost()
  SLEPPGrader = new Grader(criteria)

  # extract default parameters
  defaults = new DefaultParameters(data, merit).defaults


  # Classes used to hide / show parameters for
  # certain plans
  parameter_classes = {
    fas_years                     : "FAS"
    base_mutiplier                : "FAS"
    multiplier_bonus              : "FAS"
    NRA                           : "FAS"
    ERA                           : "FAS"
    early_reduction_factor        : "FAS"
    additional_fas_growth         : "FAS"
    employer_contrib_rate         : "CB"
    guarantee                     : "CB"
    cap                           : "CB"
    cap_bonus                     : "CB"
    ror_sigma                     : "CB"
  }


  # change the plan type ratio buttons to reflect
  # current parameters
  setPlanTypeAssumptions = (opts) ->

    $("#merit-radio input")
      .prop("checked", false)
    $("#merit-radio input#" + opts.merit_level)
      .prop("checked", true)

    $("#ss-radio input")
      .prop("checked", false)
    $("#ss-radio input#" + opts.calculate_social_security)
      .prop("checked", true)

    $("#plan-radio input")
      .prop("checked", false)
    $("#plan-radio input#" + opts._PLAN_TYPE)
      .prop("checked", true)



  # ----------------------------------------
  #
  # Plan reset undo functionality
  #
  # ----------------------------------------
  undo =
    params : null
    model : null
    toggle : ->
      if @params != null
        @model.animateUpdate(@params)
        setPlanTypeAssumptions(@model.parameters)
        return @reset()
      else
        @params = bgs.copy @model.params()
        @model.reset()
        setPlanTypeAssumptions(@model.parameters)
        d3.select("#preset-reset").text("UNDO")
    reset : ->
        d3.select("#preset-reset").text("RESET")
        @params = null
        return @
    bind : (model) ->
      @model = model
      self = @
      d3.selectAll '.rangeslider'
        .on 'click', -> self.reset()


  # ----------------------------------------
  #
  # Create all FAS models needed
  #
  # ----------------------------------------

  model_callback = (alternate, cost_plan) ->
    return ->
      # Calculate costs and update bar chart
      p = @parameters
      cost_calc.update(
        cost_plan.params(bgs.copy(p)).calcCost()
      )

      # Keep grading plan at startage = 25
      alternate.parameters = bgs.copy(p)
      alternate.set('start_age', 25)

      # Calculate grades based on current plan output
      SLEPPGrader.updateGrades alternate
      # change tooltips
      d3.selectAll('.grade_cell').each ->
        cell = d3.select(@)
        variable = cell.attr('class').split(" ")[1]
        # Get html to display in tooltip from grader
        insert = SLEPPGrader.grade_text[variable]
        # change data-title
        $(@).attr('data-original-title', insert)
            .tooltip('fixTitle')

  ### Additional FAS model for use in grading ###
  FAS_alternate = new FAS
    name : "Alternate"
    parameters : defaults

  CB_alternate = new CashBalance
    name : "CB_alternate"
    parameters : defaults


  ### ----------------------------------
      one plan for every starting age
      for calculating total cost
      ----------------------------------
  ###
  # Equations not to evaluate for
  # cost calculation plans
  cost_EQ_skip = [
    "net_accrual", "benefit75",
    "replacement", "accrual", "net_accrual",
    "wealth", "net_wealth", "social_security"
  ]

  CB_Cost_Plan = new CashBalance
    name : "CB_Cost_Plan"
    parameters : defaults
    eq_skip : cost_EQ_skip
    costCalculator : new CBCost(still_working)

  FAS_Cost_Plan = new FAS
    name : "FAS_Cost_Plan"
    parameters : defaults
    eq_skip : cost_EQ_skip
    costCalculator : new FASCost(weights)


  ###
      ----------------------------------
      ----------------------------------
  ###



  ###
      ----------------------------------
        Alternate models for plotting
      ----------------------------------
  ###

  alternate_plot_CB = {}
  alternate_plot_FAS = {}
  start = defaults["start_age"]
  tooltiptitles = [start]
  colors = [
    "#1696d2",
    "#fcb918",
    "#000000",
    "#c6c6c6"
  ]

  $legend = d3.select("#legend")
  $legend.append('span')
        .attr('id', 'title')
        .text("Starting Age")

  legend_colors = {"Main" : colors[0]}

  $legend.append('span')
    .attr('id', "Main")
    .html """
      <span
        class="legend"
        style="background-color:#{colors[0]};">
      </span> #{start}
    """

  for age, i in [35, 45]

    name = "alternate_#{age}"


    legend_colors[name] = colors[i + 1]
    $legend.append('span')
      .attr('id', "#{name}")
      .html """
        <span
          class="legend"
          style="background-color:#{legend_colors[name]};">
        </span> #{age}
      """

    tooltiptitles.push "#{age}"

    alternate_plot_CB[name] = new CashBalance({
      name : name
      parameters : defaults
      lock : ["start_age"]
    }).set('start_age', age, true)

    alternate_plot_FAS[name] =  new FAS({
      name : name
      parameters : defaults
      lock : ["start_age"]
    }).set('start_age', age, true)


  $('#legend>span').click ->
    series = @id
    if series
      $element = d3.select(@)
      hide = not $element.classed('disabled-series')

      $element.classed 'disabled-series', hide

      $element.select('span.legend').style 'background-color', ->
        if hide then "#aaa" else legend_colors[series]

      hide_elements = [
        '.Modeler-line.' + series,
        '.Modeler-hover-point.' + series
      ].join(", ")

      d3.selectAll(hide_elements).classed 'hidden', hide



  ###
      ----------------------------------
        Main Display models
      ----------------------------------
  ###

  CB_Main = new CashBalance
    name : "Main"
    parameters : defaults
    alternate_plans : alternate_plot_CB
    runCallback : model_callback CB_alternate, CB_Cost_Plan

  FAS_Main = new FAS
    name : "Main"
    parameters : defaults
    alternate_plans : alternate_plot_FAS
    runCallback : model_callback FAS_alternate, FAS_Cost_Plan

  FAS_Main.run()
  .addPlot({
    variables : ["benefit75"]
    renderTo : "#chart1"
    title : "Pension Benefit at Age 75"
    skip_hr : true
    colors : colors
    tooltiptitles : tooltiptitles
    tthtml : info_text["benefit75"]
  })
  .addPlot({
    variables : ["wealth"]
    renderTo : "#chart2"
    title : "Value of Total Lifetime Pension Benefits"
    colors : colors
    tooltiptitles : tooltiptitles
    tthtml : info_text["wealth"]
  })
  .addPlot({
    variables : ["net_wealth"]
    renderTo : "#chart3"
    title : "Value of Lifetime Pension Benefits, Net of Employee Contributions"
    colors : colors
    tooltiptitles : tooltiptitles
    tthtml : info_text["net_wealth"]
  })
  .addPlot({
    variables : ["net_accrual"]
    renderTo : "#chart4"
    title : "Annual Change in Net Value of Lifetime Pension Benefits"
    colors : colors
    tooltiptitles : tooltiptitles
    tthtml : info_text["net_accrual"]
  })
  .addPlot({
    variables : ["gov_equiv_rate"]
    renderTo : "#chart5"
    yFormat : ".2%"
    title : "Career-Average Annual Employer Costs as % of Salary"
    colors : colors
    tooltiptitles : tooltiptitles
    tthtml : info_text["gov_equiv_rate"]
  })
  .addPlot({
    variables : ["replacement"]
    yFormat : ".1%"
    renderTo : "#chart6"
    title : "Age-75 Replacement Rate"
    colors : colors
    tooltiptitles : tooltiptitles
    tthtml : info_text["replacement"]
  })
  .dumpSliders({
    renderTo : '#assumptions'
    classes : parameter_classes
    parameters : [
      {
        v : "inflation",
        cap : [0, 0.06],
        name: "Inflation Rate",
        descr : info_text["inflation"]
      }
      {
        v : "wage_growth",
        cap : [0, 0.075],
        name: "Add. Salary Growth",
        descr : info_text["wage_growth"]
      }
      {
        v : "start_salary",
        formatter : d3.format('$,'),
        cap : [25000, 60000]
        name: "Starting Salary",
        descr : info_text["start_salary"]
      }
      {
        v : "ror",
        cap : [0, 0.1],
        name: "Interest Rate",
        descr : info_text["ror"]
      }
      {
        v : "ror_sigma",
        cap : [0, 0.1],
        name: "Interest Std Dev.",
        descr : info_text["ror_sigma"]
      }
      {
        v : "discount",
        cap : [0, 0.1],
        name: "Discount Rate",
        descr : info_text["discount"]
      }
    ]
  })
  .dumpSliders({
    renderTo : '#parameters'
    classes : parameter_classes
    parameters : [
      {
        v : "fas_years",
        cap : [1,5],
        name: 'Years in FAS calc.',
        descr : info_text["fas_years"]
      }
      {
        v : "base_mutiplier",
        cap : [0, 0.04],
        name: "Salary Multiplier",
        descr : info_text["base_mutiplier"]
      }
      {
        v : "vest_years",
        cap : [0,10],
        name: 'Years to Vest',
        descr : info_text["vest_years"]
      }
      {
        v : "NRA",
        cap : [60,69],
        name: 'Normal Ret. Age',
        descr : info_text["NRA"]
      }
      {
        v : "ERA",
        cap : [52,60],
        name: 'Early Ret. Age',
        descr : info_text["ERA"]
      }
      {
        v : "early_reduction_factor",
        cap : [0, 0.1],
        name: "Early Ret. Penalty",
        descr : info_text["early_reduction_factor"]
      }
      {
        v : "multiplier_bonus",
        cap : [0, 0.002],
        name: "Multiplier Bonus",
        descr : info_text["multiplier_bonus"]
      }
      {
        v : "additional_fas_growth",
        cap : [0, 0.04],
        name: "Early Quit Bonus",
        descr : info_text["additional_fas_growth"]
      }
      {
        v : "guarantee",
        cap : [0,0.06],
        name: 'Return Guarantee',
        descr : info_text["guarantee"]
      }
      {
        v : "cap",
        cap : [0,0.12],
        name: 'Maximum Return',
        descr : info_text["cap"]
      }
      {
        v : "cash_out",
        cap : [0, 0.1],
        name: 'Refund Interest',
        descr : info_text["cash_out"]
      }
      {
        v : "employer_contrib_rate",
        cap : [0,0.12],
        name: 'Employer Contrib.',
        descr : info_text["employer_contrib_rate"]
      }
      {
        v : "employee_contrib_rate",
        cap : [0,0.12],
        name: 'Employee Contrib.',
        descr : info_text["employee_contrib_rate"]
      }
      {
        v : "cola",
        cap :[0,0.06],
        name: 'Living Cost Adj.',
        descr : info_text["cola"]
      }
    ]
  })

  # activate a model in the interface
  active_model = null
  re_render_timeout = null
  activateModel = (model, transition) ->
    undo.bind(model)

    ### redraw d3 components when the window is resized ###
    d3.select(window).on 'resize', ->
      $('.plot-panel-body.collapse').not('.in').collapse('show');
      merit_plot.draw()
      model.reRender()

    # transfer attributes and exchange
    active_model?.transfer(model)
    active_model = model
    active_model.run(null, transition)

  # Activate Social Security button
  $('#ss-radio input').change ->
    enable = (this.value == "yes")
    FAS_Main.set('calculate_social_security', enable, true)
    CB_Main.set('calculate_social_security', enable, true)
    active_model.run(null, true)

  # Activate Social Security button
  $('#merit-radio input').change ->
    level = @value
    FAS_Main.set('merit_level', level, true)
    CB_Main.set('merit_level', level, true)
    merit_plot.update([parseFloat(y),v] for y, v of merit[level])
    active_model.run(null, true)

  # default model to FAS
  undo.model = FAS_Main
  activateModel FAS_Main
  $('.slider-control.CB').hide()


  # ----------------------------------------
  #
  # Bind Page Events
  #
  # ----------------------------------------

  $('[data-toggle="tooltip"]').tooltip()

  ### reset the FAS model when the baseline button is clicked ###
  d3.select("#preset-reset").on 'click', -> undo.toggle()

  # # collapse all parameters
  $(".collapse").not('.plot-panel-body').collapse()

  # plan toggle button
  lag_plan = null
  $('#plan-radio input').change ->
    active = this.value
    if active != lag_plan
      lag_plan = active
      if active == "CB"
        activateModel CB_Main, true
        $('.slider-control.FAS').hide(400)
        $('.slider-control.CB').show(400)
      else
        activateModel FAS_Main, true
        $('.slider-control.CB').hide(400)
        $('.slider-control.FAS').show(400)
      active_model.parameters._PLAN_TYPE = active
