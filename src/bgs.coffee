###
  bgs module - Helpful functions
  Ben Southgate
  9/11/14
###

isObject = (e) -> e instanceof Object
isArray = (e) -> e instanceof Array
isFunction = (e) -> e instanceof Function

###
    Object Deep Copy
    Recursively navigate and copy properties of an
    object, replacing those of a default object if provided
###
copy = (obj, defaults) ->
  ### If not passed an object, simply return ###
  if not isObject(obj)
    return if defaults and not isObject(defaults) then defaults else obj
  ### Deep copy defaults ###
  defaults = if defaults then copy(defaults) else {}
  ### if the object is an array, recurse through it ###
  if isArray(obj)
    def = if isArray(defaults) then defaults else null
    return (copy(e, def) for e in obj)
  ### Loop through new values, overwriting defaults ###
  for key of obj
    def = defaults[key]
    prop = obj[key]
    ### if a value is an object, recursively progress ###
    if isObject(prop) and not (isArray(prop) or isFunction(prop))
      ### check that default value is similarly not an array ###
      def = def if isObject(def) and not (isArray(def) or isFunction(def))
      ### recurse deeper ###
      defaults[key] = copy(prop, def)
    else if isArray(prop)
      ### check that default value is also an array ###
      def = def if isArray(def)
      ### recurse deeper ###
      defaults[key] = (copy(e, def) for e in prop)
    else
      defaults[key] = prop
  ### return updated defaults ###
  return defaults


### Object comprehension ###
obj = (list) ->
  out = {}
  for p in list
    out[p[0]] = p[1]
  return out

### Flatten list tree ###
flatten = (arr) ->
  out = []
  for e in arr
    if isArray e
      out = out.concat flatten e
    else
      out.push e
  return out

### function that can operate on any mix of value or (nested) arrays ###
arrayFunc = (f) -> (vals...) -> f flatten vals

### functional sugar ###
map = (arr, f) -> f(v) for v in arr
reduce = (arr, f) ->
  [out, rest...] = arr
  for v in rest
    out = f out, v
  return out

### cleaner math functions ###
pow = (x, p) -> Math.pow x, p
abs = (x) -> Math.abs x
round = (x) -> Math.round x

min     = arrayFunc (v) -> Math.min.apply Math, v
max     = arrayFunc (v) -> Math.max.apply Math, v
product = arrayFunc (v) -> reduce v, (a,b) -> a*b
mean    = arrayFunc (v) -> sum(v) / v.length

cap = (v, bounds) ->
  [low, high] = bounds
  [low, high] = [high, low] if high < low
  Math.max low, Math.min(high, v)

# Complementary error function
# From Numerical Recipes in C 2e p221
erf = (x) ->
  z = Math.abs(x)
  t = 1 / (1 + z / 2)
  r = t * Math.exp(-z * z - 1.26551223 + t * (1.00002368 +
      t * (0.37409196 + t * (0.09678418 + t * (-0.18628806 +
      t * (0.27886807 + t * (-1.13520398 + t * (1.48851587 +
      t * (-0.82215223 + t * 0.17087277)))))))))
  if x >= 0 then r else 2 - r

sum = (arr) ->
  # sum of array
  total = 0
  for v in arr
    total += v
  return total

integrate = (f, a, b, n=10000) ->
  # integrate f over [a, b] using n subdivisions
  # http://en.wikipedia.org/wiki/Numerical_integration
  [a, b] = [b, a] if a > b
  c = (b-a)/n
  return c*( (f(a)+f(b))/2.0 + sum(f(a + k*c) for k in [0..n] by 1) )

gaussian_PDF = (mu, sigma) ->
  # return PDF for X ~ N(mu, sigma^2)
  e = Math.E
  pi = Math.PI
  sqrt = Math.sqrt
  return (x) -> ( e**((-(x-mu)**2) / (2*sigma**2)) ) / (sigma*sqrt(2*pi))

gaussian_CDF = (mu, sigma) ->
  (x) -> 0.5 * erf(-(x - mu) / (sigma * Math.sqrt(2)))

exp_bounded_ror = (mu, sigma, guarantee, cap) ->
  # compute the expected value of the rate of return
  # given upper and lower bounds
  # 10 is effectively infinity for our purposes
  PDF = gaussian_PDF(mu, sigma)
  CDF = gaussian_CDF(mu, sigma)
  return (
    guarantee*CDF(guarantee) +
    integrate(((x) -> PDF(x)*x), guarantee, cap) +
    cap*(1 - CDF(cap))
  )

zeros = (n) -> (0 for _ in [0..n] by 1)


module.exports = bgs =
  zeros : zeros
  copy : copy
  obj : obj
  arrayFunc : arrayFunc
  pow : pow
  round : round
  abs : abs
  min : min
  max : max
  sum : sum
  product : product
  flatten : flatten
  mean : mean
  map : map
  reduce : reduce
  cap : cap
  integrate : integrate
  erf : erf
  gaussian_PDF : gaussian_PDF
  gaussian_CDF : gaussian_CDF
  exp_bounded_ror : exp_bounded_ror

