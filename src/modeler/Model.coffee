###
  Pension Model Base Class
  Ben Southgate (bsouthga@gmail.com)
  12/05/14
###


bgs = require '../bgs.coffee'
Plot = require './Plot.coffee'
Slider = require './Slider.coffee'


module.exports = class Model

  constructor : (opts) ->

    @name = opts.name
    @parameters = bgs.copy opts.parameters
    @default_parameters = bgs.copy opts.parameters
    @runCallback = opts.runCallback
    @variables = {}
    @plots = {}
    @sliders = {}
    @alternate_plans = opts.alternate_plans
    @lock = if opts.lock then bgs.obj([p, true] for p in opts.lock) else {}
    @costCalculator = opts.costCalculator

    # Store equations
    @equations = []
    for eq in opts.equations
      # Ensure all necesary parameters are included
      eq.valid @parameters
      @equations.push eq

  calcCost : -> @costCalculator?.calc(@)

  set : (name, value, no_calc) ->
    @parameters[name] = value
    if not no_calc
      @run()
    return @

  run : (parameters, transition) ->
    @parameters = bgs.copy(parameters, @default_parameters) if parameters
    # evaluate alternate plans if necessary
    if @alternate_plans
      for name, plan of @alternate_plans
        plan.params(@parameters).run()
    (@variables[eq.name] = eq.evaluate(@)) for eq in @equations
    for p of @plots
      series = @series(@plot_vars[p])
      if @alternate_plans
        for name, plan of @alternate_plans
          series = series.concat(plan.series(@plot_vars[p]))
      @plots[p].data(series, transition)
    @runCallback?.call(@)
    return @

  params : (parameters) ->
    if not parameters
      return @parameters
    else
      for p of parameters
        if not @lock[p]
          @parameters[p] = parameters[p]
      return @

  getData : (v) ->
    out = ({x : parseInt(a), y : @variables[v][a]} for a of @variables[v])
    {name : "#{v}-#{@name}", data : out.sort((a, b) -> (a.x>b.x)-(a.x<b.x))}

  series : (vl) ->
    ###
      Returns list of series objects containing series
      Defaults to all variables, or returns list of variables
      provided
    ###
    vl = if vl and vl instanceof Array then vl else [vl]
    if vl
      (@getData(x) for x in vl)
    else
      (@getData(v) for v of @variables)

  print : ->
    console.log(
      "Parameters for #{@name}:\n", @parameters,
      "\nResults for #{@name}:\n", @variables
    )
    return @

  transfer : (otherModel) ->
    # transfer all the model plots
    # and sliders to another model
    otherModel.plots = @plots
    otherModel.plot_vars = @plot_vars
    otherModel.sliders = @sliders
    # Change model context for plots
    for p of otherModel.plots
      otherModel.plots[p].model = otherModel
    # Change model context for sliders
    for s of otherModel.sliders
      otherModel.sliders[s].updateBinding(otherModel)
    # remove linkages to this model
    @plot_vars = @plots = @sliders = null
    return @

  addPlot : (opts) ->
    o = opts
    self = @

    render_vars = (v for v in o.variables when v of @variables)
    o.series = @series(if render_vars then render_vars else null)

    extra = []
    if @alternate_plans
      for name, plan of @alternate_plans
        extra = extra.concat plan.series(render_vars)

    o.series = o.series.concat extra

    o.variable ?= o.variables.toString().replace(",","-")
    o.name ?= o.variable
    o.model = self
    o.xExtent = [0,50]
    # convert plot data to years of service
    o.subset = (data) ->
      start_age = data[0].x
      ({x : d.x - start_age, y : d.y} for d in data)

    # Keep track of what variables are associated with this plot
    @plot_vars ?= {}
    @plot_vars[o.name] = if render_vars then render_vars else null

    if o.type != "column"
      o.mouseover = (plot_context, chart_container, model) ->
        ### Several contexts are used in this function...
              chart_container : refers to the chart container div
              plot_context : refers to the Plot Object
              model : refers to the Model Object
        ###
        ### x value for mouse position over chart container ###
        mouse_x = plot_context.x.invert(
                    d3.mouse(chart_container)[0] - plot_context.margin.left
                  )
        xDom = plot_context.x.domain()
        new_x = Math.round(Math.max(xDom[0], Math.min(xDom[1], mouse_x)))
        # constrain mouseover
        p_d = plot_context.series[0].data
        sub = plot_context.subset(p_d)
        if new_x > sub[sub.length-1].x
          return
        ### Loop through all plots associated with model and
            update their lines to match the x value hovered over ###
        for pl of model.plots
          # Get the current plot
          p = model.plots[pl]
          # If the plot has a vertical line for hovering
          # and associated text and point, then update
          if p.hoverLine and p.hoverPoint
            # Get the x value of the integer age of nearest to the mouse
            x = p.x(new_x)
            # Move tooltip
            tooltip = p.tooltip
            buf = 7
            w = tooltip.node().getBBox().width + buf
            plot_width = p.width
            tooltip.attr 'transform', ->
              if plot_width < (x + w)
                "translate(#{x-w})"
              else
                "translate(#{x + buf})"
            # display service years
            p.xText.text("YOS: #{new_x}" )
            # Move the vertical lign to the correct postion
            p.hoverLine.attr({"x1": x,"x2": x})
            # Each series has its own point and text for mouseover
            for s, i in p.series
              hovpoint = p.hoverPoint[i]
              # Get the correct Y value for that series
              yval = (fmt) ->
                p.yDisplay(
                  p.container.select('.Modeler-line#' + s.name).node(),
                  x, fmt
                )
              #Move the point to the correct y postion
              y = yval(true)
              tt_text = p.svg.select(".tooltip-values##{s.name}")
              set_text_x = ->
                w = tt_text.node().getBBox().width
                return p.tt_width - w - 10
              # if the series has a y value at this x value, show
              if y != false
                tt_text.text(yval())
                  .attr 'x', set_text_x
                hovpoint.attr({
                  'cx' :  x,
                  'cy' : p.y(y)
                }).classed('out-of-bounds', false)
              else
                tt_text.text("N/A")
                  .attr 'x', set_text_x
                hovpoint.classed('out-of-bounds', true)
    # Add the plot to the list of plots for this model
    @plots[o.name] = new Plot(o)
    return @

  reRender : (opts) ->
    # Re-size all the sliders and plots
    @plots[p].d3Init().draw(null,true) for p of @plots

  addSlider : (opts) ->
    # Add a new slider to the interface for this model
    if not opts.parameter
      throw "Parameter necessary for slider."

    if not opts.parameter of @parameters
      throw "Invalid paramter : #{opts.parameter}"

    self = @
    ### Default domain to +/- 50% of starting value ###
    start = @parameters[opts.parameter]
    opts.domain ?= [
      if start > 0 then start - 0.5*start else start + 0.5*start,
      if start > 0 then start + 0.5*start else start - 0.5*start
    ]
    opts.name = opts.name or opts.parameter
    opts.fontSize = 12
    opts.model = self
    ###
      Default sliding function
      called with model context
    ###
    opts.slide ?= (value) ->
      @animationTimeout = clearTimeout(@animationTimeout)
      @set(opts.parameter, value)

    opts.start = @default_parameters[opts.parameter]
    @sliders[opts.parameter] = new Slider(opts)
    return @

  dumpSliders : (opts) ->
    ###
      Create sliders for all parameters of the model,
      placing them in new divs in the container given
      by opts.renderTo
    ###
    opts.parameters ?= Object.keys(@parameters)
    @sliderDumpOptions = bgs.copy(opts)
    container = d3.select(opts.renderTo)
    count = 1
    for param in opts.parameters
      p = param.v
      if (
        typeof @parameters[p] == "number" and
        not (opts.skip and opts.skip.indexOf(p)!=-1)
        )
        id = 'MSlider'+(++count)
        int_param = @parameters[p] > 1
        container.append('div').attr('id', id)
        slider_opts =
          snap : int_param
          renderTo : "##{id}"
          parameter : p
          name : param.name
          description : param.descr
          slide : opts.slide
          class : opts.classes[p]
          formatter : (
            param.formatter or if @parameters[p] > 1
                                  (v)->v
                                else
                                  d3.format(".3%")
          )
        slider_opts["domain"] = param.cap
        @addSlider(slider_opts)
    return @

  animateUpdate : (newparams, time, callback) ->

    self = @

    if not newparams
      return @reset(time)

    start = bgs.copy(@parameters)
    end = bgs.copy(newparams, start)
    self = @
    params = self.parameters
    interpers = bgs.obj(
      [p, d3.interpolateNumber(start[p], end[p])] for p of params
    )

    interpolate = (t) ->
      # Calculate the interpolated
      # state of all parameters between
      # the starting and ending values
      # at the given time t
      for p of params
        if typeof params[p] == "number"
          interpolated = interpers[p](t)
          relevant_slider = self.sliders[p]
          if relevant_slider
            interpolated = relevant_slider.snap(interpolated)
            relevant_slider.calculate = false
            relevant_slider.$slider.val(interpolated).change()
            if t == 1
              relevant_slider.calculate = true
          params[p] = interpolated
      self.run()

    iterations = (time or 200) / 10
    count = 0

    @animationTimeout = clearTimeout(@animationTimeout)

    run = ->
      # Animate the transition
      # between the starting and ending
      # parameter values
      self.animationTimeout = setTimeout(
        ->
          interpolate(count++ / iterations)
          if count <= iterations
            run()
          else
            callback?()
        , 10
      )

    run()
    return @

  reset : (time) ->
    if time == 0
      @parameters = bgs.copy(@default_parameters)
      @run()
    else
      console.log("reseting")
      @animateUpdate(@default_parameters, time)
    return @

  updateSliders : ->
    for p, slider of @sliders
      slider.calculate = false
      slider.$slider.val(@parameters[p]).change()
      slider.calculate = true
    return @

  paramBuilder : (param) ->
    if param instanceof Function
      param
    else if typeof param == "number"
      -> param
    else
      console.log(param)
      throw "Invalid parameter passed to function builder."

