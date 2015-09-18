###
  -----------------------------------
  Pension grading Logic for Interactive SLEPP Pension Tool
  Ben Southgate - bsouthga@gmail.com
  10 / 09 / 14
  -----------------------------------
###

bgs = require '../bgs.coffee'

module.exports = class Grader

  constructor : (@criteria, @renderTo="#grade-list") ->
    self = @

    # Reference to stored object containing criteria
    # For each variable
    c = @criteria

    ### create grade table ###
    @gradeTable()

    ### Object containing f : Ratio -> Grade ###
    graderObj = bgs.obj(
      [v, do (v) -> self.gradeChecker(c[v])] for v of c
    )

    ###
      Creates a function which produces the SLEPP grades
      and detial numbers for a plan
    ###
    @grade = (plan) ->

      # get copies of current variables
      net_wealth = bgs.copy(plan.variables.net_wealth)
      net_accrual = bgs.copy(plan.variables.net_accrual)
      benefit = bgs.copy(plan.variables.benefit)
      social_security = bgs.copy(plan.variables.social_security)
      nominal_benefit = bgs.copy(plan.variables.nominal_benefit)
      salaries = bgs.copy(plan.variables.salaries)

      cola = plan.parameters.cola
      start = plan.parameters.start_age
      end = plan.parameters.max_ret_age
      inflation = plan.parameters.inflation

      max = Math.max
      pow = Math.pow

      ### Calculate Grading ratios ###
      ratios =

        "YGGD" : do ->
          ### rewarding younger workers ###
          max_wealth = bgs.max(net_wealth[a] for a of net_wealth)
          first10 = bgs.max(net_wealth[a] for a in [start+1..start+10])
          ratio = if max_wealth > 0 then first10 / max_wealth else 0
          return bgs.cap(ratio, [0,1])

        "DYGD" : do ->
          ### promoting a dynamic workforce ###
          max_wealth = bgs.max(net_wealth[a] for a of net_wealth)
          maxGT45 = bgs.max(net_accrual[a] for a of net_accrual)
          ratio = if max_wealth > 0 then maxGT45 / max_wealth else 0
          return bgs.cap(ratio, [0,1])

        "OLGD" : do ->
          ### Encouraging work at older ages ###
          bgs.cap(
            bgs.mean(
              net_accrual[a] / salaries[a] for a in [65..70]
            ),
            [-1,0]
          )

        "S1GD" : do ->
          # Retirement Security for Short-Term Employees
          curr_params = bgs.copy(plan.parameters)
          curr_params.fixed_takeup = 65
          benefit_sum = 0
          account_sum = 0
          cola_adj = pow(1 + cola, max(0, 70-65))
          inflation_adj = pow(1 + inflation, max(0, 70-65))
          constant_salaries = null
          for start, i in [25, 33, 41, 49, 57]
            curr_quit = start + 8
            plan.variables.salaries = salaries
            curr_params['use_current_salaries'] = true
            curr_params['start_age'] = start
            curr_params['max_ret_age'] = curr_quit
            plan.parameters = curr_params
            plan.run()
            benefit_sum += plan.variables.nominal_benefit[curr_quit]
          ss = social_security[65] / (1 + inflation)**max(0, 75-65)
          ben = benefit_sum*cola_adj/inflation_adj + ss
          plan.set('start_age', 25, true)
          plan.set('use_current_salaries', false, true)
          return bgs.cap(ben / salaries[65], [0,1])

        "S3GD" : do ->
          # Retirement Security for Long-Term Employees
          cola_adj = (1 + cola)**max(0, 70-65)
          inflation_adj = (1 + inflation)**max(0, 70-65)
          ss = social_security[65] / (1 + inflation)**max(0, 75-65)
          ben = ss + nominal_benefit[65]*cola_adj/inflation_adj
          bgs.cap(ben / salaries[65], [0,1])

      ### Get the letter grades from the ratios determined above ###
      numGrade = (letter) -> "FDCBA".indexOf(letter)
      letGrade = (number) ->
        "FDCBA".charAt(bgs.cap(Math.round(number), [0,4]))
      ### return grades ###
      grades = bgs.obj([v , graderObj[v](ratios[v])] for v of ratios)
      ratios["OVRL"] = bgs.mean(numGrade(grades[v]) for v of grades)
      grades["OVRL"] = letGrade(ratios["OVRL"])
      # Store self references to calculated grades and ratios
      self.grades = grades
      self.ratios = ratios
      # Method chaining
      return self

  gradeTable : ->

    table = d3.select(@renderTo).append('table')

    rowdata = [
      ["OVRL", "Overall Grade"]
      ["YGGD", "Rewarding Younger Workers"]
      ["DYGD", "Promoting a Dynamic Workforce"]
      ["OLGD", "Encouraging Work at Older Ages"]
      ["S1GD", "Retirement Income for Short-Term Employees"]
      ["S3GD", "Retirement Income for Long-Term Employees"]
    ]

    rows = table.selectAll('tr')
            .data(rowdata)
            .enter()
            .append('tr')
            .attr 'class', (d) -> "grade_cell " + d[0]
            .attr
              "data-toggle" : "tooltip"
              "data-trigger" : "hover"
              "data-placement" : "left"
              "data-html" : "true"
              "data-title" : "(insert html)"
              "data-container" : "body"

    rows.append('td')
      .attr 'class', 'grade_div_container'
      .append('div')
      .attr 'class', "grade_div C"
      .text('C')

    rows.append('td')
      .attr 'class', "grade_description"
      .text (d) -> d[1]



  ###
    Returns function which checks if a number is in
    the interval in the grading critera (or equal to the given number)
    Example interval string "(0,0.23423]" or "0.8"
  ###
  intervalFunction : (interval_string) ->
    ### Interval regular expressions ###
    invalid_regex = /[^\-\[\]\(\)\,\.\d+]/gi
    interval_regex = /(\[|\().+\,.+(\)|\])/gi
    bounds_regex = /[\[\]\)\(]/gi
    ### Remove invalid characters ###
    s = interval_string.replace(invalid_regex, "");
    ### test for an interval in the cleaned string ###
    if interval_regex.test(s)
      left_inc = s.charAt(0) == "["
      right_inc = s.charAt(s.length-1) == "]"
      interval = (
        Number(a) for a in s.replace(bounds_regex, "").split(",")
      )
    else if /\d*\.?\d+/.test(s)
      single_number = Number(s.match(/-?\d*\.?\d+/)[0])
    else
      return null
    ### Return a function which tests if a value is in the interval ###
    if single_number != undefined
      do (single_number) -> (n) -> Math.min(n,1) == single_number
    else if interval != undefined
      (n) ->
        n = Math.min(n, 1)
        [a, b] = interval
        lower = n > a or (left_inc and n == a)
        upper = n < b or (right_inc and n == b)
        return lower and upper
    else
      throw "Invalid interval string : #{interval_string}"

  ### Returns a function which provides a grade for a number
      given an object containing the criteria for each grade ###
  gradeChecker : (var_criteria) ->
    self = @
    checkers = {}
    for letter of var_criteria
      checkers[letter] = do (letter) ->
        self.intervalFunction(var_criteria[letter])
    return (n) ->
      for letter of checkers
        if checkers[letter](n)
          return letter

  ### Update the grade divs with the new grades ###
  updateGrades : (plan) ->
    # Calculate new grades for plan
    @grade plan
    # Create text for mouseover
    @gradeDetail()
    # Update all the grade divs
    for v of @grades
      g = @grades[v]
      d3.select(".grade_cell." + v + " div.grade_div")
          .attr("class", "grade_div " + g)
          .html(g)
    return @

  ### Description of the reason for the grade ###
  gradeDetail : ->
    self = @
    fmt = d3.format(".2%")
    get = (v) -> [self.grades[v], self.ratios[v]]
    @grade_text = {
      "OVRL" : do ->
        [G, R] = get("OVRL")
        "
          <div class='grade_tooltip_header'><b> Overall Grade </b></div>
          <span class=\"grade_div minigrade #{G}\">#{G}</span> because
          the plan GPA is <b>#{d3.format('.2f')(R)}</b>
        "
      "YGGD" : do ->
        ### rewarding younger workers ###
        [G, R] = get("YGGD")
        a = "accumulate"
        "
          <div class='grade_tooltip_header'><b> Rewarding Younger Workers</b></div>
          <span class=\"grade_div minigrade #{G}\">#{G}</span> because 25-year-old hires
          #{if G in 'CD' then a+' only' else if G == "F" then 'do not '+a+' any' else a}
          #{if G != 'F' then '<b>'+fmt(R)+'</b> of the maximum value of their' else''}
          lifetime pension benefits, net of their own contributions,
          in the first 10 years of service.
        "
      "DYGD" : do ->
        ### promoting a dynamic workforce ###
        [G, R] = get("DYGD")
        "
          <div class='grade_tooltip_header'><b>Promoting a Dynamic Workforce</b></div>
          <span class=\"grade_div minigrade #{G}\">#{G}</span> because 25-year-old hires
          #{if G in ['A', 'B'] then 'never earn more than' else 'earn'}
          <b>#{fmt(R)}</b> of the accumulated value of their lifetime pension
          benefits in a single year.
        "
      "OLGD" : do ->
        ### Encouraging work at older ages ###
        [G, R] = get("OLGD")
        top = "<div class='grade_tooltip_header'><b>Encouraging Work at Older Ages</b></div>"
        if G != "A"
          "#{top} <span class=\"grade_div minigrade #{G}\">#{G}</span>
            because lifetime pension benefits net of employee
            contributions fall <b>#{fmt(-R)}</b> on average for each year worked
            between ages 65 and 70
          "
        else
          "#{top} <span class=\"grade_div minigrade #{G}\">#{G}</span> because lifetime
            pension benefits continue to increase after age 65"
      "S1GD" : do ->
        ###Providing Retirement Income to Short-Term Employees###
        [G, R] = get("S1GD")
        "
          <div class='grade_tooltip_header'>
            <b>Providing Retirement Income to Short-Term Employees</b>
          </div>
          <span class=\"grade_div minigrade #{G}\">#{G}</span> because retirees
            who change jobs every 8 years recieve
          pension benefits at age 70 that replace <b>#{fmt(R)}</b> of their age-64 earnings.
        "
      "S3GD" : do ->
        ###Providing Retirement Income to Long-Term Employees###
        [G, R] = get("S3GD")
        "
          <div class='grade_tooltip_header'>
            <b>Providing Retirement Income to Long-Term Employees</b>
          </div>
          <span class=\"grade_div minigrade #{G}\">#{G}</span>
          because retirees with 40 years of service receive
          pension benefits at age 70 that replace <b>#{fmt(R)}</b> of their age-64 earnings.
        "
    }
    return self
