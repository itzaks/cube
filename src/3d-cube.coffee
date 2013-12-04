class Cube
  action: false
  top: 0
  side: 0
  x: 0
  y: 0
  action: null
  interacted: false

  constructor: (@$wrap, @size = 200, options) ->
    @settings = 
      horizontal: true
      vertical: true

    #override defaults
    @settings[key] = value for key, value of options

    @$cube = @$wrap.find(".cube")

    @cube = @$cube[0]
    @sides = @$cube.children()

    @$wrap.css(
      width: size
      height: size
    )

    @treshold = @size/4
    @transformProp = @transformSupport [
      "transform",
      "WebkitTransform", 
      "MozTransform", 
      "OTransform", 
      "msTransform"
    ]

    @transitionDurationProp = @transformSupport [
      "transitionDuration",
      "WebkitTransitionDuration",
      "MozTransitionDuration",
      "OTransitionDuration",
      "msTransitionDuration"
    ]

    @is3D = @transformProp isnt null

    @reset()
    @bind()

  translatecube: ->
    style = ["", "translateZ(-#{ @size/2 }px) rotateY(0deg) rotateX(0deg)"]

    @$cube[0].style[@transformProp] = style[@is3D * 1]

  translatefaces: () ->
    faces = @$cube.children()
    transform = 
      ".top": "rotateX(90deg) translateZ(#{ @size/2 }px)"
      ".front": "translateZ(#{ @size/2 }px)"
      ".right": "rotateY(90deg) translateZ(#{ @size/2 }px)"
      ".back": "rotateY(180deg) translateZ(#{ @size/2 }px)"
      ".left": "rotateY(-90deg) translateZ(#{ @size/2 }px)"
      ".bottom": "rotateX(-90deg) rotate(180deg) translateZ(#{ @size/2 }px)"

    for className, style of transform
      style = "" unless @is3D
      faces.filter(className)[0].style[@transformProp] = style

  translate: (coords) ->
    {x, y} = coords
    @x = x if typeof x is "number"
    @y = y if typeof y is "number"
    
    if @is3D
     @cube.style[@transformProp] = "translateZ(-#{ @size/2 }px) rotateX(#{ @y }deg) rotateY(#{ @x }deg)"
    else 
      @cube.style[@transformProp] = "translateX(#{ x }px)"

  repositionTop: (spin) ->
    @sides.filter('.top')[0].style[@transformProp] = "rotateX(90deg) translateZ(#{ @size/2 }px) rotateZ(#{ spin }deg)"
    @sides.filter('.bottom')[0].style[@transformProp] = "rotateX(-90deg) translateZ(#{ @size/2 }px) rotateZ(#{ spin * -1 }deg)"

  reset: ->
    sizes = [@sides.length * @size, "100%"]
    xpos = if @is3D then @side * 90 else @side * @size
    ypos = if @is3D then @top * 90 else false

    @translate x: xpos, y: ypos
    @translatefaces()
    @translatecube()

    @$wrap.toggleClass("is-flat", !@is3D)

    @$cube.css("width", sizes[@is3D * 1])
    @sides.css("width", @size)

    if @is3D then @repositionTop(0)

  bind: ->
    #keyin'
    $(document).on "keydown", (evt) =>
      move = null
      
      switch evt.keyCode
        when 37 then move = x: @x + 90
        when 38 then move = y: @y + 90
        when 39 then move = x: @x - 90
        when 40 then move = y: @y - 90
        when 27 then @reset()
        else return

      @translate move
      @repositionTop @x if move.x isnt undefined

    #cube events
    Hammer(@$cube.parent()[0]).on('touch mouseover tap click', (ev) =>
      @handleTouch(ev)
    )

    #all over!
    Hammer($("body")[0], 
      drag_min_distance: 0
      drag_lock_to_axis: on
    ).on('drag dragstart dragend', (ev) =>
      @handleTouch(ev) if @activated
    )

  transformSupport: (props) ->
    el = document.createElement("div")
    prop = null
    return prop for prop in props when typeof el.style[prop] isnt "undefined"

  mode: (which) ->
    @is3D = which is "3d"
    @reset()

  ease: (prop) ->
    prop = prop / 4
    prop = Math.min(@size, Math.abs(prop)) * sign(prop)

  drag: (ev) ->
    sideways = ev.gesture.direction in ["left", "right"]

    return if @settings.vertical is false and !sideways
    return if @settings.horizontal is false and sideways

    @action ?= if sideways then "leftright" else "updown"

    which = if @action is "leftright" then "deltaX" else "deltaY"
    change = sign(ev.gesture[which])

    return if change is 0

    if @action is "leftright" and @top is 0
      inertia = if @is3D then 90 else @size
      x = (@side * inertia) + (@ease ev.gesture.deltaX)
      @translate x: x

    else if @action is "updown" and @is3D
      y = @ease ev.gesture.deltaY
      @translate y: (@top*90) - y
    
    # stop browser scrolling
    ev.gesture.preventDefault()

  release: (from, ev) ->
    return if @action is "leftright" and @top isnt 0
    return unless from or from is "releasing"

    sideways = from is "leftright"

    @action = "releasing"
    @$cube.removeClass("dragging")

    setTimeout =>
      @action = null
    , 100

    which = if sideways then "deltaX" else "deltaY"
    delta = ev.gesture?[which]
    change = sign(delta) if Math.abs(delta) > @treshold


    if sideways
      if @is3D then inertia = 90 else
        #dont go past start/end side
        inertia = @size
        
        change = 0 if (@side is 0 and change is 1) or (-@side is @sides.length-1 and change is -1)

      @side += change if change
      @translate x: (@side * inertia)
      @repositionTop (@side * 90) if @is3D

    else if @is3D
      @top -= change if change
      @top = 1 if @top > 1
      @top = -1 if @top < -1
      @translate y: @top * 90

  interacted: ->
    return if @hasInteracted
    
    @hasInteracted = true
    @$wrap.toggleClass("has-interacted", true)



  handleTouch: (ev) =>
    switch ev.type
      when 'touch'
        @dragged = false
        @activated = true
        @interacted()
        @$cube.addClass("dragging")

      when 'click'
        return if @dragged

        link = $(ev.target).data "link"
        
        window.open link if link
          

      when "dragend"
        return unless @action or @action is "releasing" or !ev.gesture
        @activated = false
        @release(@action, ev)
        @action = null

      # when we dragdown
      when "drag"
        @dragged = true
        return if @action is "releasing" or ev.gesture is undefined
        @drag(ev)
        
sign = (x) ->
  (if x then (if x < 0 then -1 else 1) else 0)

window.Cube = Cube
