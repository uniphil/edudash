# Karma configuration
# http://karma-runner.github.io/0.12/config/configuration-file.html
# Generated on 2015-03-02 using
# generator-karma 0.8.3

module.exports = (config) ->
  config.set
    # base path, that will be used to resolve files and exclude
    basePath: '../'

    # testing framework to use (jasmine/mocha/qunit/...)
    frameworks: ['jasmine']

    # list of files / patterns to load in the browser
    files: [
      # 3rd-party libs
      'bower_components/angular/angular.js'
      'bower_components/angular-mocks/angular-mocks.js'
      'bower_components/angular-animate/angular-animate.js'
      'bower_components/angular-aria/angular-aria.js'
      'bower_components/angular-cookies/angular-cookies.js'
      'bower_components/angular-messages/angular-messages.js'
      'bower_components/angular-resource/angular-resource.js'
      'bower_components/angular-route/angular-route.js'
      'bower_components/angular-sanitize/angular-sanitize.js'
      'bower_components/angular-touch/angular-touch.js'
      'bower_components/angular-ui-select/dist/*.js'
      'bower_components/angular-rangeslider/angular.rangeSlider.js'
      'bower_components/angular-translate/angular-translate.js'
      'bower_components/angular-translate-loader-static-files/angular-translate-loader-static-files'
      'bower_components/underscore/underscore.js'

      # modules (must be added manually because they must be included first)
      'app/scripts/services/service.coffee'
      'app/scripts/controllers/controller.coffee'
      'app/scripts/directives/directive.coffee'
      'app/scripts/filters/filter.coffee'
      'app/scripts/lib/leafletMap/leafletMap.coffee'

      # everything else (must be after every module has been added)
      'app/scripts/**/*.coffee'

      # tests
      'test/mock/**/*.coffee'
      'test/spec/**/*.coffee'
    ],

    # list of files / patterns to exclude
    exclude: []

    # web server port
    port: 8080

    # level of logging
    # possible values: LOG_DISABLE || LOG_ERROR || LOG_WARN || LOG_INFO || LOG_DEBUG
    logLevel: config.LOG_INFO

    # Start these browsers, currently available:
    # - Chrome
    # - ChromeCanary
    # - Firefox
    # - Opera
    # - Safari (only Mac)
    # - PhantomJS
    # - IE (only Windows)
    browsers: [
      'PhantomJS'
    ]

    # Which plugins to enable
    plugins: [
      'karma-phantomjs-launcher'
      'karma-jasmine'
      'karma-coffee-preprocessor'
    ]

    # enable / disable watching file and executing tests whenever any file changes
    autoWatch: true

    # Continuous Integration mode
    # if true, it capture browsers, run tests and exit
    singleRun: false

    colors: true

    preprocessors: '**/*.coffee': ['coffee']

    # Uncomment the following lines if you are using grunt's server to run the tests
    # proxies: '/': 'http://localhost:9000/'
    # URL root prevent conflicts with the site root
    # urlRoot: '_karma_'
