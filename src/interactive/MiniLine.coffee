###
    Small line charts for assumptions
    Ben Southgate (bsouthga@gmail.com)
    12/11/14
###

bgs = require '../bgs.coffee'

module.exports = class MiniLine

  constructor : (opts) ->
    @container = d3.select(opts.renderTo)
    @series = opts.series
    @title = opts.title
    @draw()

  draw : ->
    self = @

    # empty container
    @container.html('')

    # get container dimensions
    form_width = $(@container.node())
            .parents('form')[0]
            .getBoundingClientRect().width

    # render new svg to fit
    margin = { top: 30, right: 20, bottom: 40, left: 40 }
    width = form_width - margin.left - margin.right
    height = 150 - margin.top - margin.bottom

    svg = @container.append('svg')
      .attr('width', width + margin.left + margin.right)
      .attr('height', height + margin.top + margin.bottom)
    .append('g')
      .attr('transform', 'translate(' + margin.left + ',' + margin.top + ')')


    # generate scales based on current data
    df = @df = @series
    max_yos = @max_yos = d3.max(df, (d) -> d[0])

    p = d3.format(".1%")


    x = @x = d3.scale.linear()
          .domain d3.extent(df, (d) -> d[0])
          .range [0, width]

    y = @y = d3.scale.linear()
          .domain d3.extent(df, (d) -> d[1])
          .range [height, 0]

    xAxis = d3.svg.axis()
        .scale(x)
        .ticks(5)
        .outerTickSize(0)
        .tickFormat (d) -> d
        .orient("bottom")

    yTicks = 4

    yAxis = @yAxis = d3.svg.axis()
        .scale(y)
        .ticks(yTicks)
        .tickFormat(p)
        .outerTickSize(0)
        .orient("left")

    yGrid = @yGrid = d3.svg.axis().scale(y)
            .ticks(yTicks)
            .tickSize(width, 0)
            .tickFormat("")
            .orient("left")

    line = @line = d3.svg.line()
              .interpolate("cardinal")
              .x (d) -> x(d[0])
              .y (d) -> y(d[1])

    # render y axis
    y_axis_g = @y_axis_g = svg.append("g")
        .attr("class", "y axis miniline")
        .call(yAxis)


    helper = d3.select('body').append('svg')


    y_title = svg.append('g').append('text')
                .text("Years of Service")
                .attr 'class', 'y-title miniline'
                .attr 'y', height + margin.bottom - 10
                .attr 'x', ->
                  text = d3.select(@).text()
                  t = helper.append('text')
                          .attr('class', @class)
                          .text(text)
                  w = t.node().getBBox().width
                  t.remove()
                  (width - w) / 2



    title = svg.append('g').append('text')
                .text(@title)
                .attr('class', 'miniline-title')
                .attr('y', -15)
                .attr 'x', ->
                  text = d3.select(@).text()
                  t = helper.append('text')
                          .attr('class', @class)
                          .text(text)
                  w = t.node().getBBox().width
                  t.remove()
                  (width - w) / 2 + 20

    helper.remove()

    # render x axis
    svg.append("g")
        .attr("class", "x axis miniline")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis)

    # y grid lines
    y_grid_g = @y_grid_g = svg.append('g')
      .attr('class', 'grid miniline')
      .attr("transform", "translate(" + width + ",0)")
      .call(yGrid)

    @path = svg.append('path')
            .attr
              class : 'miniline line'
              d : line(df)

    hovercircle = svg.append('circle')
                  .attr
                    class : 'miniline hovercircle hidden'
                    cx : 0
                    cy : height
                    r : 4

    hovertext = svg.append('text')
                    .attr
                      class : 'miniline hovertext hidden'
                      x : 0
                      y : height
    get_x = ->
      [mx, my] = d3.mouse(self.container.node())
      x_val = Math.round(self.x.invert(mx - margin.left))
      return bgs.cap(x_val, [0, self.max_yos])

    @container.on 'mousemove', ->
      x_val = get_x()
      y_val = self.df[x_val][1]

      hovertext.text("#{p(y_val)}")
        .attr
          x : x(x_val) + 5
          y : y(y_val) - 3

      hovercircle
        .attr
          cx : x x_val
          cy : y y_val

    @container.on 'mouseover', ->
      hovercircle.classed('hidden', false)
      hovertext.classed('hidden', false)

    @container.on 'mouseout', ->
      hovercircle.classed('hidden', true)
      hovertext.classed('hidden', true)


  update : (data) ->
    @df = data

    t = (s) -> s.transition().duration(400)

    @x.domain d3.extent(data, (d) -> d[0])
    @y.domain d3.extent(data, (d) -> d[1])

    t(@y_axis_g).call(@yAxis)
    t(@y_grid_g).call(@yGrid)
    t(@path).attr('d', @line(data))

    return @