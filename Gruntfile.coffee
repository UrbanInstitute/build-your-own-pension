#
# Build System for Modeler Project
# Ben Southgate
# 10/07/14
#

deploy_path_list = [
  'B:/bsouthga/Modeler'
  'B:/build-your-own-pension/'
  'T:/Bsouthga_mugroup/build-your-own-pension/'
]

css_dependencies = [
  "css/vendor/bootstrap.min.css"
  "css/main.css"
  "css/nav.css"
  "css/slider.css"
  "css/radio.css"
  "css/miniline.css"
  "css/charts.css"
  "css/grades.css"
  "css/parameters.css"
]

js_dependencies = [
  "./lib/vendor/d3.min.js"
  "./lib/vendor/queue.min.js"
  "./lib/vendor/jquery-1.11.0.js"
  "./lib/vendor/bootstrap.min.js"
  "./lib/vendor/rangeslider.min.js"
]

module.exports = (grunt) ->
  # Register configuration
  grunt.initConfig
    copy :
      deploy :
        files : [
          {
            expand: true
            cwd : "json"
            src: ['**']
            dest: "dist/json"
          }
        ].concat(
          {
            expand: true
            cwd : "dist/"
            src: ['**']
            dest: path
          } for path in deploy_path_list
        )
    uglify:
      options:
        mangle: true
        banner : """
/* --- interactive pension model (bsouthga@gmail.com) --- */

"""
      js:
        files:
          './dist/js/main.min.js' : js_dependencies.concat [
            './lib/bundle.js'
          ]
    browserify:
      dist:
        files:
          './lib/bundle.js' : ['./src/main.coffee']
        options:
          transform: ['coffeeify']
    watch:
      coffee :
        files: [
          './src/*.coffee',
          './src/interactive/*.coffee',
          './src/modeler/*.coffee'
        ],
        tasks: ['browserify']
      html :
        files : ['./index.html']
      css :
        files : ['./css/*.css']
      options :
        livereload : true
    processhtml :
      dist :
        files :
          './index_dist.html' : ['./index.html']
    htmlmin :
      dist :
        options :
          removeComments: true,
          collapseWhitespace: true
        files :
          './dist/index.html' : './index_dist.html'
    cssmin :
      options :
        keepSpecialComments : 0
        banner : """
/* --- interactive pension model (bsouthga@gmail.com) --- */

"""
      dist :
        files :
          './dist/css/main.min.css' : css_dependencies
    browserSync:
      bsFiles:
        src : [
          './src/*.coffee',
          './src/modeler/*.coffee',
          './src/interactive/*.coffee',
          './css/*.css',
          './index.html'
        ]
      options:
        watchTask: true
        server:
            baseDir: "./"

  libs = [
   'grunt-contrib-uglify'
   'grunt-contrib-watch'
   'grunt-contrib-coffee'
   'grunt-contrib-concat'
   'grunt-contrib-copy'
   'grunt-contrib-htmlmin'
   'grunt-contrib-cssmin'
   'grunt-browserify'
   'grunt-browser-sync'
   'grunt-processhtml'
  ]
  grunt.loadNpmTasks(pkg) for pkg in libs

  # Coffee compiling, uglifying and watching in order
  grunt.registerTask 'default', [
    'browserify',
    'browserSync',
    'watch'
  ]

  grunt.registerTask 'deploy', [
    'browserify'
    'uglify'
    'cssmin'
    'processhtml'
    'htmlmin'
    'copy'
  ]
