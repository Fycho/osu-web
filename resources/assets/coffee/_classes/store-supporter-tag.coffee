###
#    Copyright 2015-2017 ppy Pty. Ltd.
#
#    This file is part of osu!web. osu!web is distributed with the hope of
#    attracting more community contributions to the core ecosystem of osu!.
#
#    osu!web is free software: you can redistribute it and/or modify
#    it under the terms of the Affero GNU General Public License version 3
#    as published by the Free Software Foundation.
#
#    osu!web is distributed WITHOUT ANY WARRANTY; without even the implied
#    warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#    See the GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with osu!web.  If not, see <http://www.gnu.org/licenses/>.
###

class @StoreSupporterTag
  RESOLUTION: 8
  MIN_VALUE: 4
  MAX_VALUE: 52

  @Price = {
    price: 0
    duration: 0
    pricePerMonth: ->
      (@price / @duration).toFixed(2)
    discount: ->
      raw = if @duration >= 12 then 46 else ((1 - (@price / @duration) / 4) * 100)
      Math.round(raw, 0)
  }

  constructor: ->
    $(document).on 'turbolinks:load', =>
      @initialize(document.getElementById('js-store-supporter-tag'))

  initialize: (rootElement) =>
    return unless rootElement
    @el = rootElement
    @searching = false
    @searchData = null
    @currentUser = {
      username: @el.dataset.username
      avatar_url: @el.dataset.avatarUrl
    }
    # Everything should be scoped under the root @el
    @priceElement = @el.querySelector('.js-price')
    @durationElement = @el.querySelector('.js-duration')
    @pricePerMonthElement = @el.querySelector('.js-price-per-month')
    @discountElement = @el.querySelector('.js-discount')
    @slider = @el.querySelector('.js-slider')
    @usernameInput = @el.querySelector('#username.form-control')

    @debouncedGetUser = _.debounce @getUser, 300
    @initializeSlider()
    @initializeSliderPresets()
    @initializeUsernameInput()
    @

  initializeSlider: =>
    slider = $(@slider).slider {
      range: 'min',
      value: @MIN_VALUE * @RESOLUTION,
      min: @MIN_VALUE * @RESOLUTION,
      max: @MAX_VALUE * @RESOLUTION,
      step: 1,
      animate: 'fast',
      slide: (event, ui) =>
        @onSliderValueChanged event, ui
      change: (event, ui) =>
        @onSliderValueChanged event, ui
    }
    .slider('pips', {
      step: 4,
      rest: "label",
      labels: (value) ->
        # That's how the pip labels work ¯\_(ツ)_/¯
        return '' if value == 'first'
        return 24 if value == 'last'
        label = switch ((value - 4) / 8) + 4
                when 8 then 2
                when 12 then 4
                when 16 then 6
                when 20 then 8
                when 22 then 9
                when 24 then 10
                when 26 then 12
                when 39 then 18
                when 52 then 24
                else ''
        label
    })
    @updatePrice(@calculate(@MIN_VALUE * @RESOLUTION))
    slider

  initializeSliderPresets: =>
    $(@el.querySelectorAll('.js-slider-preset')).on 'click', (event) =>
      target = event.currentTarget
      $(@slider).slider('option', 'value', target.dataset.presetValue * @RESOLUTION)

  initializeUsernameInput: =>
    $(@usernameInput).on 'input', (event) =>
      @onInput(event)

  getUser: (username) =>
    $.post '/users/check-username-exists', username: username
    .done (data) =>
      @updateSlider(data?)
      @updateUserDisplay(data)
      @updateCart(data)
    .fail (xhr) =>
      @updateSlider(false)
      @updateUserDisplay(null)
      @updateCart(null)
      if xhr.status == 401
        osu.popup osu.trans('errors.logged_out'), 'danger'
    .always =>
      @searching = false

  calculate: (position) =>
    price = Math.floor(position / @RESOLUTION)
    duration = switch
      when price < 8 then 1
      when price < 12 then 2
      when price < 16 then 4
      when price < 20 then 6
      when price < 22 then 8
      when price < 24 then 9
      when price < 25 then 10
      when price < 28 then 10
      else
        Math.floor(price / 26.0 * 12)

    Object.assign(Object.create(StoreSupporterTag.Price), { price: price, duration: duration })

  onSliderValueChanged: (event, ui) =>
    values = @calculate(ui.value)
    @updatePrice(values)

  onInput: (event) =>
    if !@searching
      @searching = true
      # need to trigger immediately.
      # without setTimeout, some browsers might not trigger the class update
      # until after the debounce?
      setTimeout(() =>
        @updateSearchResult(true)
        @updateSlider(false)
      , 0)

    @debouncedGetUser(event.currentTarget.value)

  updateCart: (data) ->
    # FIXME: should consolidate implementations into a service class.
    disabled = !data?
    $('.js-store-add-to-cart').prop 'disabled', disabled
    $('#product-form').data 'disabled', disabled

  updateSearchResult: (searching) ->
    $('.js-input-feedback').text('searching') if searching

  updatePrice: (obj) =>
    @el.querySelector('input[name="item[cost]"').value = obj.price
    @el.querySelector('input[name="item[extra_data][duration]"').value = obj.duration
    @priceElement.textContent = "USD #{obj.price}"
    monthText = if (obj.duration == 1) then 'month' else 'months'
    @durationElement.textContent = "#{obj.duration} #{monthText}"
    @pricePerMonthElement.textContent = obj.pricePerMonth()
    @discountElement.textContent = obj.discount()

  updateUserDisplay: (user) =>
    avatarUrl = if user
                   $('.js-input-feedback').text('')
                   user.avatar_url
                 else
                   $('.js-input-feedback').text("This user doesn't exist")
                   ''

    $(@el.querySelectorAll('.js-avatar')).css(
      'background-image': "url(#{avatarUrl})"
    )

  updateSlider: (enabled) =>
    $(@el).toggleClass('store-supporter-tag--disabled', !enabled)
    $('.js-slider').slider({ 'disabled': !enabled })
