# Interactive SLEPP Pension Modeler


## Installation

[NodeJS](http://nodejs.org/) is required to build.

To install dependencies, run:

```
npm install
npm install -g grunt-cli
npm install -g coffee-script
```

## Running Model server/desktop-side through NodeJS

The Model code can be used to simulate pensions on the desktop by running the code through NodeJS. See [model_test.coffee](https://github.com/UrbanInstitute/build-your-own-pension/blob/master/test/model_test.coffee) for an example usage.

```
coffee model_test.coffee
```

## Building Web Application


"grunt" to build the project and start a dev server

```
grunt
```

run "grunt deploy" to push the distribution code to the server

```
grunt deploy
```