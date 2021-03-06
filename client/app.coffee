getTemplate = (name) -> if Session.equals("lang", "en") then "en_#{name}" else name

setScrollPosition = ->
  if window.location.hash
    $el = $(window.location.hash)
    if $el[0]
      Meteor.setTimeout (-> $el[0].scrollIntoView()), 100
    else
      Meteor.setTimeout (-> setScrollPosition()), 1000
  else
    window.scrollTo 0,0

Router.configure
  layoutTemplate: "body"
  loadingTemplate: "loading"
  notFoundTemplate: "error404"

Router.onRun ->
  NProgress.start()

Router.onBeforeAction ->
  lang = Session.get "lang"
  @render getTemplate("header"), to: "header"
  @render getTemplate("footer"), to: "footer"

Router.onAfterAction ->
  NProgress.done()
  setScrollPosition()
  Meteor.setTimeout reattachBehavior, 0
  Meteor.setTimeout setTitle, 0

setTitle = ->
  if Session.equals("page", "home") or Session.equals("page", "") or Session.equals("page", undefined)
    document.title = "Q42"
  else
    document.title = $('h1').first().text() + " - Q42"
  $("#og-title").attr "content", document.title

Router.map ->

  @route "home",
    path: "/"
    onBeforeAction: -> Session.set("page", "home")
    action: -> @render getTemplate("home")

  @route "blog",
    path: "/blog"
    action: ->
      if @ready()
        @render getTemplate("blog")
      else
        @render "loading"
    onBeforeAction: -> Session.set "page", "blog"
    onAfterAction: -> Meteor.call "checkTumblr"
    waitOn: ->
      [
        SubsManager.subscribe "blogpostIndex", 1
        SubsManager.subscribe "pagesByTag", ""
        SubsManager.subscribe "LatestComments", 10
      ]
    data: ->
      posts = blogpostIndex.find {}, sort: date: -1
      return {
        post:       posts
        pagination: getPagination 1
      }

  @route "blog",
    path: "/blog/page/:pageNum"
    action: ->
      if @ready()
        @render getTemplate("blog")
      else
        @render "loading"
    onBeforeAction: -> Session.set "page", "blog"
    onAfterAction: -> Meteor.call "checkTumblr"
    waitOn: ->
      [
        SubsManager.subscribe "blogpostIndex", @params.pageNum * 1
        SubsManager.subscribe "pagesByTag", ""
        SubsManager.subscribe "LatestComments", 10
      ]
    data: ->
      posts = blogpostIndex.find {}, sort: date: -1
      return {
        post:       posts
        pagination: getPagination @params.pageNum
      }

  @route "blog",
    path: "/blog/tagged/:tag"
    action: ->
      if @ready()
        @render getTemplate("blog")
      else
        @render "loading"
    onBeforeAction: -> Session.set "page", "blog"
    onAfterAction: -> Meteor.call "checkTumblr"
    waitOn: ->
      [
        Meteor.subscribe "pagesByTag", @params.tag or ""
        SubsManager.subscribe "blogpostIndex", 1, @params.tag
        SubsManager.subscribe "LatestComments", 10
      ]
    data: ->
      posts = blogpostIndex.find {}, sort: date: -1
      return null unless posts.count() > 0
      return {
        post:       posts
        pagination: getPagination @params.pageNum
        tag:        @params.tag
      }

  @route "blogpost",
    path: "/blog/post/:id?/:title?"
    onBeforeAction: ->
      Session.set "page", "blog"
      Session.set "blogpostid", @params.id * 1
    action: ->
      if @ready()
        @render getTemplate("blogpost")
      else
        @render "loading"
    waitOn: -> [
      Meteor.subscribe "blogpostFull", @params.id * 1
      Meteor.subscribe "blogComments", @params.id * 1
      SubsManager.subscribe "blogpostIndex", 1
      SubsManager.subscribe "LatestComments", 10
    ]
    data: ->
      return null unless blogpostFull.findOne()
      return {
        post:           blogpostFull.findOne()
        comments:       BlogComments.find({}, sort: date: -1)
        commentsCount:  BlogComments.find().count()
        oneComment:     BlogComments.find().count() is 1
      }

  @route "vacatures",
    path: "/vacatures"
    action: ->
      if @ready()
        @render getTemplate("vacatures")
      else
        @render "loading"
    onBeforeAction: -> Session.set "page", "vacatures"
    onAfterAction: -> Meteor.call "checkTumblr"
    waitOn: ->
      [
        Meteor.subscribe "pagesByTag", "vacature"
        SubsManager.subscribe "blogpostIndex", 1, "vacature"
        SubsManager.subscribe "LatestComments", 10
      ]
    data: ->
      posts = blogpostIndex.find {}, sort: date: -1
      return null unless posts.count() > 0
      return {
        post:       posts
        pagination: getPagination 1
        tag:        "vacature"
      }

  @route "io",
    path: "/io"
    action: ->
      if Session.equals("lang", "nl")
        Spiderable.httpStatusCode = 404
        @render "error404"
        return

      if @ready()
        @render getTemplate("io")
      else
        @render "loading"
    onBeforeAction: -> Session.set "page", "io"
    onAfterAction: -> Meteor.call "checkTumblr"
    waitOn: ->
      [
        Meteor.subscribe "pagesByTag", "io"
        SubsManager.subscribe "blogpostIndex", 1, "io"
        SubsManager.subscribe "LatestComments", 10
      ]
    data: ->
      posts = blogpostIndex.find {}, sort: date: -1
      return null unless posts.count() > 0
      return {
        post:       posts
        pagination: getPagination 1
        tag:        "io"
      }

  @route "page",
    path: "/:page"
    onBeforeAction: -> Session.set "page", @params.page
    action: ->
      if Session.equals("lang", "en") and Template["en_" + @params.page]
        return @render "en_" + @params.page
      else if Template[@params.page]
        @render @params.page
      else
        Spiderable.httpStatusCode = 404
        @render "error404"

  @route "404",
    path: "*"
    onBeforeAction: ->
      Session.set "page", "404"
      Spiderable.httpStatusCode = 404
    action: ->
      @render "error404"

getPagination = (pageNum, tag) ->
  pageNum = pageNum * 1
  item = PageCounts.findOne tag: (tag or "")
  pages = if item then item.count else 1
  lang = Session.get "lang"
  older = if lang is "en" then "older" else "ouder"
  newer = if lang is "en" then "newer" else "nieuwer"
  items = []

  if pages isnt 1
    page = pageNum or 1
    if page > 1
      items.push label: newer, page: page - 1

    min = Math.max 1, page - 3
    max = Math.min pages, page + 3

    for i in [min..max]
      items.push label: i, page: i, active: i is page

    if page < pages
      items.push label: older, page: page + 1

  return items
