###
  Results series plots
  Ben Southgate (bsouthga@gmail.com)
  12/05/14
###

bgs = require '../bgs.coffee'

series_model_name = (s) -> s.name.split('-')[1]

module.exports = class Plot

  constructor : (opts) ->
    ###Store options###
    @options = opts
    @model = opts.model

    ###unique Plot name###
    @name = opts.name.replace(/\W/g, '')

    ###reference to the element to contain the chart###
    if not opts.skip_hr
      d3.select(opts.renderTo).append('div')
        .attr('class', 'divider')
        .append('hr')

    @panel = d3.select(opts.renderTo)
                  .append('div')

    @panelTitle = @panel.append('div')
                  .classed('title-text', true)

    @panelBody = @panel.append('div')
                    .attr('class', 'plot-panel-body collapse in')
                    .attr('id', @name)

    @panelDescription = @panelBody.append('div')
                  .classed('panel-description', true)
                  .html(opts.tthtml)

    # start with plot description hidden
    $(@panelDescription.node()).hide()

    @container = @panelBody.append('div')
                  .classed('plot-body', true)
                  .classed('Modeler-chart', true)

    ###Data Subset function###
    @subset = opts.subset or (data) -> data

    ### Y text format ###
    @yFormat = opts.yFormat
    @fixed = opts.fixed
    @mouseover = opts.mouseover
    @xExtent = opts.xExtent
    @tooltiptitles = opts.tooltiptitles

    ###Initialize d3 dimensions, set container,
    and create scale / drawing functions###
    @d3Init opts

    ###Draw the chart###
    @draw opts

    ###Current y value of mouse while dragging###
    @downy = Math.NaN

    ###Enable y zooming by default###
    if false != opts.yZoom
      ###Bind zoom events to the object containing the graph###
      @container
          .on "mousemove.drag", @mousemove()
          .on "touchmove.drag", @mousemove()
          .on "mouseup.drag",   @mouseup()
          .on "touchend.drag",  @mouseup()

    ###The graph has been rendered###
    @options.initialized = true


  extent : (opts, new_domain) ->
    self = @
    opts ?= @options
    ###Find the minimum and maximum y values out of all given series###
    min_val = Infinity
    max_val = -Infinity
    @seriesIndex = {}
    for s, i in @series
      @seriesIndex[s.name] = i
      subset = @subset(s.data)
      low = d3.min subset, (d) -> d.y
      high = d3.max subset, (d) -> d.y
      min_val = low if (low < min_val)
      max_val = high if (high > max_val)

    ###Domain of y scale###
    @yDomain ?= opts.yDomain
    replacement = (
      new_domain or
      @yDomain or
      [Math.min(0, min_val), Math.max(Math.abs(min_val), max_val)]
    )

    # keep min at zero if above
    #replacement[1] = replacement[1]*1.05 if replacement[1] > 0
    replacement[0] = 0 if replacement[0] > 0

    @y.domain(replacement)
    @y_0 = Math.max(0, self.y.domain()[0])
    return @

  d3Init : (opts) ->
    ###
      **************************************************
      Initialize d3 scaling, axis, and drawing functions
      **************************************************
    ###
    self = @
    opts ?= @options
    @initialized = opts.initialized = @renderedXtitle = false
    ###Default width of chart to width of parent container###
    container_width = opts.width or parseInt(@panel.style('width'))
    container_height = opts.height or parseInt(@container.style('height'))*0.9
    ###Default margin, overriding any defaults if provided in opts###
    @margin = bgs.copy(
      opts.margin or {},
      {top:15,right:10,bottom:40,left:70}
    )
    ###Default height to 50% of width (without margin)###
    @height = (
      container_height or
      container_width*0.5
    )
    @height -= (@margin.top + @margin.bottom)
    ###Add margin to width###
    @width = container_width - @margin.left - @margin.right
    ###Scaling functions defined on dimension settings###
    @x = d3.scale.linear().range [0, @width]
    ###Y scaling function###
    @y = d3.scale.linear().range([@height, 0])
    ###Axis drawing functions based on scales###
    @xAxis = d3.svg.axis()
        .scale @x
        .ticks opts.xTicks or 8
        .orient "bottom"
    ###
      - Set Y Axis Bounds.
      Default to [min(all series), max(all series)], can be
      manually set using opts.yDomain
    ###
    (@series ?= opts.series).sort (a, b) ->
      a_max = d3.max(a, (d) -> d.y)
      b_max = d3.max(b, (d) -> d.y)
      (a_max < b_max) - (a_max > b_max)

    @extent(opts)

    ext = @xExtent ? d3.extent(@subset(@series[0].data), (d) -> d.x)
    @x.domain(ext)

    ###Line and area path generators###
    @line = d3.svg.line()
      .x (d) -> self.x(d.x)
      .y (d) -> self.y(d.y)
      .interpolate "monotone"

    ###Remove previous svg###
    d3.select("svg.#{@name}").remove()

    ###Append base svg to container element###
    @svg = @container.append("svg")
        .attr('class', @name)
        .attr("width", @width + @margin.left + @margin.right)
        .attr("height", @height + @margin.top + @margin.bottom)
      .append("g")
        .attr("width", @width)
        .attr("height", @height)
        .attr("transform", "translate(#{@margin.left},#{@margin.top})")

    return @

  drawYAxis : (opts) ->
    opts ?= @options
    self = @
    ###Remove previous axis containers###
    self.svg.selectAll('g.Modeler-AXCont').remove()
    ###Insert an axis container at the bottom of the SVG layer cake###
    gy = self.svg.insert('g',':first-child')
        .attr('class', 'Modeler-AXCont')
      .selectAll("g.y") #Add the new lines
        .data(self.y.ticks(@yTicks or 6), String)
        .attr("transform", (d) -> "translate(0," + self.y(d) + ")")
    ### axis text ###
    f = self.yFormat
    gy.select("text")
        .text(self.y.tickFormat(
          @yTicks or 6, if f == undefined then "$," else f
        ))
    ### new axis container ###
    gye = gy.enter().insert("g", "a")
        .attr({
          "class" : (d) -> if d == 0 then "y zero" else "y"
          "transform" : (d) -> "translate(0," + self.y(d) + ")"
          "background-fill" : "#FFEEB6"
        })
    ###y axis grid lines###
    gye.append("line")
        .style('opacity', 0.7)
        .attr({
          "stroke" : (d) -> if d then "#ccc" else "#000"
          "x1" : 0
          "x2" : @width
        })
    ###y axis ticks###
    gye.append("text")
        .text(self.y.tickFormat(
          @yTicks or 6,if f == undefined then "$," else f
        ))
        .attr({
          "class" : "axis"
          "x" : -3
          "dy" : ".35em"
          "text-anchor" : "end"
        })
    ###bind drag events to axis upon (re)rendering###
    if false != opts.yZoom
      gye.select('text').style("cursor", "ns-resize")
        .on("mousedown.drag",  self.yaxis_drag())
        .on("touchstart.drag", self.yaxis_drag())

  draw : (opts, redraw) ->
    ###
      *************************************************
      Add Chart SVG container to DOM and draw axes
      *************************************************
    ###
    opts ?= @options
    self = @
    @drawYAxis()
    ###
     Render the graph
    ###
    if @initialized
      @data()
    else
      ###
      Add the color and area rendering in the order of the data
      from the series with the greatest maximum to the series
      with the smallest maximum, alowing all to be hovered over initially
      ###
      @container.selectAll(
        '.Modeler-line, g.x.axis'
      ).remove()

      for s, i in @series
        s.color = (
          opts.colors[i%opts.colors?.length]
        )

      ###Add lines after area so all lines are selectable###
      for s in @series
        @plot_graphic = @svg.append("path")
            .datum(@subset(s.data))
            .attr({
              "id" : s.name
              # use model name for class
              "class" : "Modeler-line " + series_model_name(s)
              "stroke" : s.color
              "d" : @line
            })
        @plot_graphic.style("stroke-dasharray", "4,6") if (opts.dash)

      ###Add x axis###
      @svg.append("g")
          .attr("class", "x axis")
          .attr("transform", "translate(0," + @height + ")")
          .call(@xAxis)

      if not @renderedXtitle
        @renderedXtitle = true
        x_title = "Years of Service (YOS)"
        @svg.append("text")
            .attr("class", "x axis text")
            .attr "transform", ->
              h = self.svg.append("text").text(x_title)
              w = h.node().getBBox().width
              h.remove()
              "translate(#{[(self.width/2-w/2), self.height+35]})"
            .text(x_title)

      ###Add the title text###
      if not @titleRendered or redraw
        @title(opts)
        @titleRendered = true

      # Remove if already exists
      @hoverLine?.remove()
      # Add new vertical line to appear on mouseover
      @hoverLine = @svg.append('line')
        .attr({
            "class" : "Modeler-hover-line"
            "x1" : 0
            "x2" : 0
            "y1" : 0
            "y2" : self.y.range()[0]
            "stroke" : "#ccc"
          }).style({
            "stroke-width" : 1
          }).style('opacity', 0)


      @hoverPoint?.map (x) -> x.remove()
      @hoverPoint = []

      # the order of the y text elements need
      # to be in reverse order of the series
      n_series = @series.length - 1

      # Add new Y text elements and points
      # to appear on mouse over plot
      for s, i in @series
        @hoverPoint.push(
          @svg.append('circle')
            .attr({
              'class' : "Modeler-hover-point " + series_model_name(s)
              'id' : s.name
              'r' : 4
              'cy' : 0
              'cx' : 0
            }).style({
              'fill' : "#eee"
              'stroke' : s.color
              'stroke-width' : 2
            }).classed('out-of-bounds', true)
        )

      @svg.select('.linechart.tooltip').remove()

      @tooltip = @svg.append('g')
                      .attr("class" , "linechart tooltip")
                      .style('opacity', 0)


      y_buffer = 15
      x_buffer = 5

      @tt_width = tooltip_width = 110
      tooltip_height = 25 + (@series.length+1)*y_buffer
      tooltip_padding = 10

      @tooltip.append('rect')
            .attr({
              "width" : tooltip_width,
              "height" : tooltip_height,
              "rx" : 5,
              "ry" : 5
            }).style({
              fill : "#fff",
              opacity : 0.8,
              stroke : "#aaa"
            })

      @xText = @tooltip.append('text')
        .attr('class', 'linechart x-text')
        .attr('y', y_buffer)
        .attr('x', x_buffer)

      @tooltip.append('text')
        .attr('y', y_buffer*2)
        .attr('x', x_buffer)
        .text("Starting Age: ")

      # append series tooltip items
      @tt_series = @tooltip.append('g').selectAll('g')
        .data(@series)
        .enter()
        .append('g')
        .attr 'transform', (d, i) ->
          "translate(#{x_buffer}, #{30 + (i+1)*y_buffer})"

      rect_width = 10
      rect_height = 5
      @tt_series.append('rect')
        .attr
          width : rect_width
          height : rect_height
          y : -(y_buffer - rect_height) /2
          rx : 3
          ry : 3
        .style
          fill : (d) -> d.color

      @tt_series.append('text')
        .attr('x', rect_width + 5)
        .text (d, i) -> self.tooltiptitles[i]

      @tt_values = @tt_series.append('text')
        .attr('class', 'tooltip-values')
        .attr('x', tooltip_width - 70)
        .attr("id", (d) -> d.name)
        .text("(change)")

      hl = ->
        d3.selectAll([
          '.linechart.tooltip'
          '.Modeler-hover-line'
          '.Modeler-hover-text'
          ].join(", "))
          .transition().duration(100)

      ###call the mouseover with the context of the plot###
      @container.on('mousemove', -> self.mouseover?(self, @, self.model))
        .on 'mouseover', -> 
            hl().style('opacity', 1)
            d3.selectAll('.Modeler-hover-point')
              .classed('out-of-bounds', false)
        .on 'mouseout', -> 
            hl().style('opacity', 0)
            d3.selectAll('.Modeler-hover-point')
              .classed('out-of-bounds', true)

    return @


  title : (opts) ->
    ###
      *************************************************
      Create title box
      *************************************************
    ###
    self = @
    opts ?= @options
    title_text = opts.title or opts.name or "Chart"
    icons = @panelTitle.html(title_text)
      .append('div')
      .attr('class', 'plot-more')

    info = icons.append('i').attr('class', 'fa fa-info-circle')
    collapse = icons.append('i')
                  .attr
                    'class' : 'fa fa-chevron-circle-up'
                    'data-toggle' : 'collapse'
                    'data-target' : '.plot-panel-body#' + @name

    @showInfo = true
    info.on 'click', ->
      if self.showInfo
        self.showInfo = false
        $(self.panelDescription.node()).show(400)
      else
        self.showInfo = true
        $(self.panelDescription.node()).hide(400)


    return @

  ### convert mouse pixel xy to data values ###
  invertX : (xPos) -> @x.invert(xPos)

  ###Get correct y value to display in tooltip###
  yDisplay : (point, x_val, unformatted) ->
    mouse_x_value = @invertX(
      if x_val != undefined then x_val else d3.mouse(point)[0]
    )
    data = @subset(@series[@seriesIndex[point.id]].data)
    display_y_value = Infinity
    smallest_dist = Infinity
    ###find the y value corresponding to the x value
    closest to the mouse x position###
    max_val = d3.max(data, (d) -> d.x)
    if max_val < mouse_x_value
      return false

    for d in data
      curr_dist = Math.abs(d.x - mouse_x_value)
      if smallest_dist > curr_dist
        smallest_dist = curr_dist
        display_y_value = d.y
    ### format y value and return ###
    f = @yFormat
    f = if f == undefined then "$,.0f" else f
    if display_y_value < Infinity
      if not unformatted
        d3.format(f)(display_y_value)
      else
        display_y_value
    else
      null

  yaxis_drag : ->
    self = @
    return ->
      document.onselectstart = -> false
      p = d3.mouse(self.svg.node())
      self.downy = self.y.invert(p[1])

  mousemove : ->
    ###
      -------------------------
        MOUSE MOVEMENT EVENTS
      -------------------------

      Y AXIS DRAGGING:

        If the y Axis has been dragged, calculate the
        change in the mouse's position from the point at which the
        axis was clicked to the current position of the mouse.

        Then, adjust the axis boundaries by reducing or increasing them
        based on their relative contribution to the
        extent of the axis (around 0).

    ###
    self = @
    self.add_bottom = self.y_0 > 0
    ###Return function for execution upon mouse movement in chart###
    return ->
      p = d3.mouse(self.svg.node())
      ###
        Y AXIS Event
        check to see if we have grabbed the y axis
      ###
      if not isNaN(self.downy)
        d3.select('body').style("cursor", "ns-resize")
        ###Get the old axis bounds from the graph###
        oldDomain = self.y.domain()
        ###Get the current position of the mouse###
        rupy = self.y.invert(p[1])
        ###Get the old top and bottom of the y axis###
        [yBottom, yTop] = oldDomain
        ###Calculate the absolute difference between the top and bottom###
        ext = Math.abs(yBottom - yTop)
        ###Calculate the ratio of the y Axis domain that
        falls above 0 and below 0###
        above_0 = if yTop >= 0
            (yTop - self.add_bottom*yBottom)/ext
          else
            0
        below_0 = if yBottom <= 0 then yBottom/ext else 0
        ###If we haven't moved the mouse over 0 (can't divide by 0!)
        update the y axis and redraw the chart###
        if rupy != 0
          ###Calculate the ratio of change in the position of the
          mouse from first click to current value###
          changey = self.downy / rupy
          ###Calculate the new absolute distance between the
          bottom and top values of the axis###
          extent_change = Math.abs(ext * changey)
          ###Assign the relative amounts of the above difference
          to the region of the plot below and above the 0 point###
          top = above_0*(extent_change + yBottom*self.add_bottom)
          bottom = if yBottom > 0 then yBottom else below_0*extent_change
          new_domain = [bottom, top]
          ###Update the y scaling functions domain and redraw the chart###
          self.y.domain(new_domain)
          self.draw()
        ###Stop other events from happening while we drag the axis###
        d3.event.preventDefault()
        d3.event.stopPropagation()

  mouseup : ->
    self = @
    return ->
      document.onselectstart = -> true
      d3.select('body').style("cursor", "auto")
      if not isNaN(self.downy)
        self.draw()
        self.downy = Math.NaN
        d3.event.preventDefault()
        d3.event.stopPropagation()

  data : (new_series, transition) ->
    ###
      **************************************************
      Update data for given list of new_series
      **************************************************
    ###
    # enable line transitions
    t = (selection) ->
      if transition
        selection.transition().duration(300)
      else
        selection

    old_domain = @y.domain()
    new_series ?= @series
    self = @
    max_val = -Infinity
    min_val = Infinity

    ### Find new extent of data and re-adjust y axis ###
    for s in new_series
      new_max = d3.max(s.data, (d) -> d.y)
      new_min = d3.min(s.data, (d) -> d.y)
      max_val = new_max if new_max > max_val
      min_val = new_min if new_min < min_val

    [old_min, old_max] = old_domain
    total = (Math.abs(old_min) + Math.abs(old_max))

    ### Allow values to fluxuate within quarters ###
    low_qtr = old_min + total/4
    high_qtr = old_min + total*3/4

    ### Adjust bounds when only when necessary ###
    if not @fixed
      ### New domain for y Axis ###
      @extent(null, [
         (if min_val > low_qtr
            min_val - Math.abs(old_min-low_qtr)
          else if old_min > min_val
            min_val
          else
            old_min),
         (if max_val < high_qtr
            max_val + Math.abs(old_max-high_qtr)
          else if old_max < max_val
            max_val
          else
            old_max)
      ])
      .drawYAxis() # draw new axis with new domain

    ### Update data series ###
    for s in new_series
      data = self.subset(s.data)
      if s.name of @seriesIndex
        ###Update data in series storage list###
        @series[@seriesIndex[s.name]].data = s.data
        # transition if necessary
        t(@svg.selectAll('path#' + s.name + '.Modeler-line'))
          .attr("d", @line(data))


    return @

# node exporting
try
  module?.exports = Plot
catch e