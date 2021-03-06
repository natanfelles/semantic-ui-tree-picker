$.fn.treePicker = (options) ->
  widget = $(@)
  picked = []
  nodes = []
  tabs = {}
  modal = $("""
    <div class="ui tree-picker modal">
      <i class="close icon"></i>
      <div class="header">
        #{options.name}

        <div class="ui menu">
          <a class="active tree item">
            <i class="list icon"></i> Выбрать
          </a>
          <a class="picked item">
            <i class="checkmark icon"></i> Выбранные <span class="count"></span>
          </a>
        </div>
      </div>
      <div class="ui search form">
        <div class="field">
          <div class="ui icon input">
            <input type="text" placeholder="Поиск">
            <i class="search icon"></i>
          </div>
        </div>
      </div>
      <div class="content">
        <div class="ui active inverted dimmer"><div class="ui text loader">Loading data</div></div>
        <div class="tree-tab">
          <div style="height: 400px"></div>
        </div>

        <div class="search-tab">
        </div>

        <div class="picked-tab">
        </div>
      </div>
      <div class="actions">
        <a class="pick-search"><i class="checkmark icon"></i> Выбрать все</a>
        <a class="unpick-search"><i class="remove icon"></i> Убрать все</a>
        <a class="unpick-picked"><i class="remove icon"></i> Убрать все</a>
        <a class="ui blue button accept">Принять</a>
        <a class="ui button close">Отмена</a>
      </div>
    </div>
    """).modal(duration: 200)
  count = $('.count', modal)
  tabs =
    tree: $('.tree-tab', modal)
    search: $('.search-tab', modal)
    picked: $('.picked-tab', modal)
  actionButtons =
    pickSearch: $('.actions .pick-search', modal)
    unpickSearch: $('.actions .unpick-search', modal)
    unpickPicked: $('.actions .unpick-picked', modal)

  config = {
    childrenKey: 'nodes'
    singlePick: false
    minSearchQueryLength: 3
    hidden: (node) -> false
    disabled: (node) -> false
    displayFormat: (picked) ->
      "#{options.name} (Выбрано #{picked.length})"
  }
  $.extend(config, options)

  initialize = () ->
    if config.data
      nodes = config.data

    if widget.attr("data-picked-ids")
      config.picked = widget.attr("data-picked-ids").split(",")

    if config.picked
      if nodes.length
        updatePickedNodes()
        widget.html(config.displayFormat(picked))
      else
        widget.html(config.displayFormat(config.picked))
    else
      widget.html(config.displayFormat([]))

    widget.on('click', (e) ->
      modal.modal('show')
      unless nodes.length
        if config.url
          loadNodes(config.url, {}, (nodes) ->
            $('.ui.active.dimmer', modal).removeClass('active')
            initializeNodes(nodes))
      else
        $('.ui.active.dimmer', modal).removeClass('active')
        initializeNodes(nodes)
    )

    $('.actions .accept', modal).on('click', (e) ->
      modal.modal('close')
      config.onSubmit(picked) if config.onSubmit
      widget.html(config.displayFormat(picked))
    )

    actionButtons.pickSearch.on('click', (e) ->
      $('.search-tab .node:not(.picked) .name').trigger('click')
    )

    actionButtons.unpickSearch.on('click', (e) ->
      $('.search-tab .node.picked .name').trigger('click')
    )

    actionButtons.unpickPicked.on('click', (e) ->
      $('.picked-tab .node.picked .name').trigger('click')
    )

    $('.menu .tree', modal).on('click', (e) -> showTree())
    $('.menu .picked', modal).on('click', (e)-> showPicked())
    $('.search input', modal).on('keyup', (e) -> showSearch($(@).val()))

  loadNodes = (url, params={}, success) ->
    $.get(url, params, (response) ->
      if response.constructor == String
        nodes = $.parseJSON(response)
      else
        nodes = response
      success(nodes))

  initializeNodes = (nodes) ->
    updatePickedNodes()
    tree = renderTree(nodes, height: '400px', overflowY: 'scroll')
    tabs.tree.html(tree)
    initializeNodeList(tree)

  updatePickedNodes = ->
    if config.picked
      picked = []
      for id in config.picked
        searchResult = recursiveNodeSearch(nodes, (node) -> "#{node.id}" == "#{id}")
        if searchResult.length
          picked.push(searchResult[0])

  showTree = ->
    $('.menu .item', modal).removeClass('active')
    $('.menu .tree', modal).addClass('active')
    tabs.tree.show()
    tabs.search.hide()
    tabs.picked.hide()
    modal.attr('data-mode', 'tree')

  showSearch = (query) ->
    if query isnt null and query.length >= config.minSearchQueryLength
      foundNodes = recursiveNodeSearch(nodes, (node) -> node.name and node.name.toLowerCase().indexOf(query.toLowerCase()) > -1)
      list = renderList(foundNodes, height: '400px', overflowY: 'scroll')

      $('.menu .item', modal).removeClass('active')
      tabs.search.show().html(list)
      tabs.tree.hide()
      tabs.picked.hide()
      modal.attr('data-mode', 'search')
      initializeNodeList(list)

      $('.name', list).each(() ->
        name = $(@).text()
        regex = RegExp( '(' + query + ')', 'gi' )
        name = name.replace( regex, "<strong class='search-query'>$1</strong>" )
        $(@).html(name)
      )
    else
      showTree()

  showPicked = ->
    list = renderList(picked, height: '400px', overflowY: 'scroll')

    $('.menu .item', modal).removeClass('active')
    $('.menu .picked', modal).addClass('active')
    tabs.picked.show().html(list)
    tabs.tree.hide()
    tabs.search.hide()
    modal.attr('data-mode', 'picked')

    initializeNodeList(list)

  renderTree = (nodes, css={}) ->
    tree = $('<div class="ui tree-picker tree"></div>').css(css)
    for node in nodes
      if config.hidden(node)
        continue

      nodeElement = $("""
        <div class="node" data-id="#{node.id}" data-name="#{node.name}">
          <div class="head">
            <i class="add circle icon"></i>
            <i class="minus circle icon"></i>
            <i class="radio icon"></i>
            <a class="name">#{node.name}</a>
            <i class="checkmark icon"></i>
          </div>
          <div class="content"></div>
        </div>
      """).appendTo(tree)

      if config.disabled(node)
        nodeElement.addClass('disabled')

      if node[config.childrenKey] and node[config.childrenKey].length
        $('.content', nodeElement).append(renderTree(node[config.childrenKey]))
      else
        nodeElement.addClass("childless")
    tree

  renderList = (nodes, css={}) ->
    list = $('<div class="ui tree-picker list"></div>').css(css)
    for node in nodes
      if config.hidden(node)
        continue

      nodeElement = $("""
        <div class="node" data-id="#{node.id}" data-name="#{node.name}">
          <div class="head">
            <a class="name">#{node.name}</a>
            <i class="checkmark icon"></i>
          </div>
          <div class="content"></div>
        </div>
      """).appendTo(list)

      if config.disabled(node)
        nodeElement.addClass('disabled')
    list

  initializeNodeList = (tree) ->
    $('.node', tree).each(() ->
      node = $(@)
      head = $('>.head', node)
      content = $('>.content', node)

      $('>.name', head).on('click', (e) ->
        nodeClicked(node)
      )

      node.addClass('picked') if nodeIsPicked(node)

      unless node.hasClass('childless')
        $('>.icon', head).on('click', (e) ->
          node.toggleClass('opened')
          content.slideToggle()
        )

      updatePickedIds()
    )

  nodeClicked = (node) ->
    unless node.hasClass('disabled')
      if config.singlePick
        $('.node.picked', modal).removeClass('picked')
        picked = []

      node.toggleClass('picked')
      if node.hasClass('picked')
        pickNode(node)
      else
        unpickNode(node)

  pickNode = (node) ->
    config.picked = null
    id = node.attr('data-id')
    picked.push(id: id, name: node.attr('data-name'))
    updatePickedIds()
    $(".node[data-id=#{id}]", modal).addClass('picked')

  unpickNode = (node) ->
    config.picked = null
    id = node.attr('data-id')
    picked = picked.filter((n) -> "#{n.id}" != "#{id}")
    updatePickedIds()
    $(".node[data-id=#{id}]", modal).removeClass('picked')

  nodeIsPicked = (node) ->
    picked.filter((n) -> "#{n.id}" is node.attr('data-id')).length

  updatePickedIds = ->
    widget.attr('data-picked-ids', picked.map((n) -> n.id))
    if picked.length
      count.closest('.item').addClass('highlighted')
      count.html("(#{picked.length})")
    else
      count.closest('.item').removeClass('highlighted')
      count.html("")

  recursiveNodeSearch = (nodes, comparator) ->
    results = []

    for node in nodes
      if comparator(node)
        results.push(id: node.id, name: node.name)
      if node[config.childrenKey] and node[config.childrenKey].length
        results = results.concat(recursiveNodeSearch(node[config.childrenKey], comparator))

    results

  initialize()
