#
# Function to extend model for file output
# Ben Southgate
# 01/23/15
#

fs = require 'fs'
csv = require 'fast-csv'

module.exports = (Model) ->
  #
  # add toCSV to prototype
  #
  Model::toCSV = (filename) ->

    filename ?= "model_#{@name}_output.csv"

    self = @
    csvStream = csv.createWriteStream({headers: true})
    writableStream = fs.createWriteStream(filename)

    writableStream.on "finish", ->
      console.log("Model #{self.name} written to #{filename}")

    csvStream.pipe(writableStream)

    ages = (a for a of @variables.salaries)
    for a in ages
      row = {quit_age : a}
      for name, vector of @variables
        row[name] = vector[a]
      csvStream.write(row)

    csvStream.end()
    return self
