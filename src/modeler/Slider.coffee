###
  Parameter Slider
  Ben Southgate (bsouthga@gmail.com)
  12/05/14
###

bgs = require '../bgs.coffee'

module.exports = class Slider

  ### Slider Constructor Method ###
  constructor : (opts) ->
    ### Store slider context for use in functions ###
    self = @
    ### Slider properties, providing defaults ###
    @container = d3.select(opts.renderTo)
    @name = opts?.name?.replace(/\W/g, '') ? 'slider'
    @displayName = opts.name ? @name
    @slide = opts.slide ? ->
    @domain = opts.domain ? [0,1]
    @step = if (not opts.snap) then 0.00001 else 1
    @start = opts.start ? (@domain[0] + @domain[1])*0.5
    @description = opts.description
    @model = opts.model
    @planclass = opts.class
    ### Draw the slider on construction of Slider object ###
    @draw(opts)
    @snap = if opts.snap then Math.round else (v) -> v
    @options = opts

  ### Slider Drawing Method ###
  draw : (opts) ->

    ### Store slider context for use in functions ###
    self = @
    opts ?= @options

    @formatter = opts.formatter ? d3.format(',.3g')

    control = @container.html('')
                .attr 'class', 'slider-control'

    if @planclass
      control.classed(@planclass, true)

    head = control.append 'div'
      .attr
        'class' : 'slider-head'
        'data-toggle' : 'collapse'
        'data-target' : '#slider-hide-' + @name

    @text_input = head.append 'input'
      .attr
        'type'  : 'text'
        'class' : 'slider-text-input'
        'id' : 'slider-text-' + @name
        'value' : @formatter @start

    title = head.append 'span'
              .text(@displayName)

    collapse_body = control.append 'div'
      .attr
        'class' : 'slider-hide collapse in'
        'id' : 'slider-hide-' + @name

    @slider = collapse_body.append('input')
      .attr
        'type' : 'range'
        'min' : @domain[0]
        'max' : @domain[1]
        'step' : @step
        'value' : @start
        'id' : 'slider-input-' + @name


    # reference to JQuery selection of slider input
    @$slider = $( @slider.node() )

    # Add parameter description text
    description = collapse_body.append('div')
      .attr('class', "slider-description")
      .html(@description)

    # logic for text input
    @text_input
      .on 'change', ->
        val = self.text_input.property('value').replace(/[^0-9\.]+/g,'')
        if val != ''
          val /= 100 if "%" in self.formatter(val)
          capped = bgs.cap(val, self.domain)
          self.slide.call self.model, capped
          self.$slider.val(capped).change()
          self.last_value = self.text_input.property('value')
      .on 'focus', ->
        self.last_value = self.text_input.property('value')
        self.text_input.property('value', '')
      .on 'blur', ->
        if self.last_value
          self.text_input.property('value', self.last_value)

    # variable to turn model calculation on / off
    @calculate = true
    @$slider.rangeslider
        polyfill: false,
        onSlide: (position, value) ->
          self.text_input.property('value', self.formatter value)
          if self.calculate
            self.slide.call self.model, value

    ### slide to the starting value ###
    self.slide.call self.model, self.start

    ### Return self reference for method chaining ###
    return @

  ### Slider Method to set value and text ###
  setValue : (value) ->
    ### Store slider context for use in functions ###
    @text_input.property('value', @formatter value)
    return @

  updateBinding : (otherModel) ->
    @model = otherModel
    @$slider.rangeslider
      polyfill: false,
      onSlide: (position, value) ->
        self.text_input.property('value', self.formatter value)
        if self.calculate
          self.slide.call self.model, value
