###
  Social Security Equation
  Ben Southgate (bsouthga@gmail.com)
  12/05/14
###

bgs = require '../bgs.coffee'
Equation = require './Equation.coffee'

module.exports = class SocialSecurity extends Equation

  constructor : ->

    # mitigate object chain tax
    max = Math.max
    min = Math.min
    round = Math.round
    floor = Math.floor

    formula = (p) ->

      # get calculated salaries
      salaries = @variables.salaries

      # current parameters
      cpi = p.inflation
      wg = p.wage_growth
      start = p.start_age
      end = p.max_ret_age
      start_year = 2014
      birth_year = start_year - start
      end_year = start_year + 60
      age_60_year = birth_year + 60

      if not p.calculate_social_security
        return bgs.obj([a, 0] for a in [start..end])

      # calculate average wage vector
      wage_index = 1 + cpi + wg

      # need 1977 for bend points
      ae =
        1977 : 9779.44
        1992 : 22935.42
        1993 : 23132.67
        1994 : 23753.53
        1995 : 24705.66
        1996 : 25913.90
        1997 : 27426.00
        1998 : 28861.44
        1999 : 30469.84
        2000 : 32154.82
        2001 : 32921.92
        2002 : 33252.09
        2003 : 34064.95
        2004 : 35648.55
        2005 : 36952.94
        2006 : 38651.41
        2007 : 40405.48
        2008 : 41334.97
        2009 : 40711.61
        2010 : 41673.83
        2011 : 42979.61
        2012 : 44321.67
        2013 : 45128.76

      # fill rest of ae
      ae[start_year] = 46786.77
      for year in [start_year+1..end_year] by 1
        ae[year] = ae[year-1]*(wage_index)

      # calculate tax-max
      taxmax =
        1992 : 55500
        1993 : 57600
        1994 : 60600

      # fill taxmax vector
      for year in [1995..end_year]
        taxmax[year] = max(
          taxmax[year-1]
          round( (taxmax[1994]*ae[year-2] / ae[1992])/100 )*100
        )

      # account for deflation years
      taxmax[2010] = 106800
      taxmax[2011] = 106800

      # calculate time indexed salaries
      ix = []
      if not (age_60_year of ae)
        console.log(age_60_year, birth_year)
      for age in [start..end] by 1
        year = birth_year + age
        capped = min(salaries[age], taxmax[year])
        ix.push if year < age_60_year
                  (capped / ae[year]) * ae[age_60_year]
                else
                  salaries[age]

      # average top 35 years
      aime = 0
      (aime += s) for s in ix.sort().slice(-35)
      aime /= (35*12)

      # bend points
      ratio = ae[age_60_year] / ae[1977]
      bend1 = round( 180 * ratio )
      bend2 = round( 1085 * ratio )

      # calculate pia
      pia62 = if 0 < aime <= bend1
                floor( (0.90*aime)*10 ) / 10
              else if bend1 < aime <= bend2
                floor(((0.90*bend1)+(0.32*(aime-bend1)))*10)/10
              else
                floor((
                  (0.90 * bend1) +
                  (0.32 * (bend2-bend1)) +
                  (0.15 * (aime-bend2))
                )*10)/10

      # Get normal retirement age for individual
      b = birth_year
      SocSecNRA = switch
        when (b < 1938) then 65
        when (1938 <= b <= 1942) then 65+((b-1937)*(1/6))
        when (1943 <= b <= 1954) then 66
        when (1955 <= b <= 1959) then 66+((b-1954)*(1/6))
        else 67

      # early retirement reduction
      tkup = start + 40
      reduction = if (SocSecNRA-tkup) <= 0
                    0
                  else if (SocSecNRA-tkup) >= 3
                    ((1/180)*36)+(((SocSecNRA-tkup)-3)*((1/240)*12))
                  else if 0 < (SocSecNRA-tkup) < 3
                    ((1/180)*((SocSecNRA-tkup)*12))

      # calculate credits for working past NRA
      m = (min(70,tkup)-SocSecNRA)*12*.01
      delayed_credit =  if (b < 1917)
                          0
                        else if (1916 < b < 1925)
                          (1/4)*m
                        else if (1924 < b < 1927)
                          (7/24)*m
                        else if (1926 < b < 1929)
                          (1/3)*m
                        else if (1928 < b < 1931)
                          (3/8)*m
                        else if (1930 < b < 1933)
                          (5/12)*m
                        else if (1932 < b < 1935)
                          (11/24)*m
                        else if (1934 < b < 1937)
                          (1/2)*m
                        else if (1936 < b < 1939)
                          (13/24)*m
                        else if (1938 < b < 1941)
                          (7/12)*m
                        else if (1940 < b < 1943)
                          (5/8)*m
                        else
                          (2/3)*m

      ss = (pia62+delayed_credit-reduction)*12
      out = {}
      for age in [start..end] by 1
        out[age] = ss*(1 + cpi)**(75-tkup)

      return out


    # call Equation constructor
    super
      name : "social_security"
      formula : formula
      parameters : [
        "inflation", "ror", "start_year",
        "wage_growth", "start", "max_ret_age"
      ]
