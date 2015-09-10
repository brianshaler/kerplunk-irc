gulp = require 'gulp'
glut = require 'glut'

coffee = require 'gulp-coffee'
stylus = require 'gulp-stylus'
coffeeAmdify = require 'glut-coffee-amdify'

glut gulp,
  tasks:
    coffee:
      runner: coffee
      src: 'src/**/*.coffee'
      dest: 'lib'
    components:
      runner: coffeeAmdify
      src: 'src/components/**/*.coffee'
      dest: 'public/components'
    client:
      runner: coffee
      src: 'src/public/**/*.coffee'
      dest: 'public'
    assets:
      src: 'assets/**'
      dest: 'public'
    stylus:
      runner: stylus
      src: 'src/public/css/**/*.styl'
      dest: 'public/css'
