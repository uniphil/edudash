'use strict'

###*
 # @ngdoc function
 # @name edudashApp.controller:DashboardsCtrl
 # @description
 # # DashboardsCtrl
 # Controller of the edudashApp
###
angular.module('edudashAppCtrl').controller 'DashboardCtrl', [
    '$scope', '$window', '$routeParams', '$anchorScroll', '$http', 'leafletData',
    '_', '$q', 'WorldBankApi', 'layersSrv', 'chartSrv', '$log','$location','$translate',
    '$timeout', 'MetricsSrv', 'colorSrv', 'OpenDataApi'

    ($scope, $window, $routeParams, $anchorScroll, $http, leafletData,
    _, $q, WorldBankApi, layersSrv, chartSrv, $log, $location, $translate,
    $timeout, MetricsSrv, colorSrv, OpenDataApi) ->

        # other state
        layers = {}
        currentLayer = null

        #### Template / Controller API via $scope ####

        # app state
        angular.extend $scope,
          year: null  # set after init
          viewMode: null  # set after init
          visMode: 'passrate'
          schoolType: $routeParams.type
          hovered: null
          lastHovered: null
          selected: null
          allSchools: $q -> null
          filteredSchools: $q -> null

        # state transitioners
        angular.extend $scope,
          setYear: (newYear) -> $scope.year = newYear
          setViewMode: (newMode) -> $scope.viewMode = newMode
          setVisMode: (newMode) -> $scope.visMode = newMode
          setSchoolType: (newType) -> $location.path "/dashboard/#{newType}/"
          hover: (layer) -> $scope.hovered = layer
          keepHovered: -> $scope.hovered = $scope.lastHovered
          unHover: -> $scope.hovered = null
          select: (layer) -> $scope.selected = layer


        # State Listeners

        $scope.$watchGroup ['year', 'schoolType'], ([year, schoolType]) ->
          unless year == null
            $scope.allSchools = OpenDataApi.getSchools year, schoolType

        $scope.$watchGroup ['allSchools'], ([allSchools]) ->
          $scope.filteredSchools = $q (resolve, reject) ->
            allSchools.then resolve, reject

        $scope.$watch 'filteredSchools', (schools) ->
          mapped = $q (resolve, reject) ->
            map = (data) ->
              resolve data.map (s) -> [ s.latitude, s.longitude, s ]
            schools.then map, reject
          schools.then (schools) ->
            layersSrv.addFastCircles "schools-#{$scope.schoolType}", mapId,
              getData: () -> mapped
              options:
                className: 'school-location'
                radius: 8
                onEachFeature: (data, layer) ->
                  layer.feature = data
                  colorPin layer
                  attachLayerEvents layer

        $scope.$watch 'viewMode', (newMode, oldMode) ->
          if newMode not in ['schools', 'national', 'regional']
            console.error 'changed to invalid view mode:', newMode
            return
          # unless newMode == oldMode  # doesnt work for initial render
          leafletData.getMap(mapId).then (map) ->
            unless currentLayer == null
              map.removeLayer currentLayer
              currentLayer = null

        $scope.$watch 'visMode', (newMode) ->
          if currentLayer == null
            console.warn 'no layer yet, visMode waiting..'
            return
          if newMode not in ['passrate', 'ptratio']
            console.error 'changed to invalid visualization mode:', newMode
            return
          if $scope.viewMode == 'schools'
            colorPins()
          else if $scope.viewMode == 'regional'
            colorRegions()

        $scope.$watch 'hovered', (layer, oldLayer) ->
          if layer != null
            layer.bringToFront()
            $scope.lastHovered = layer
            layer.setStyle switch $scope.viewMode
              when 'schools' then (
                color: '#05a2dc'
                weight: 5
                opacity: 1
                fillOpacity: 1 )
              when 'regional' then weight: 5, opacity: 1

          if oldLayer != null
            oldLayer.setStyle switch $scope.viewMode
              when 'schools' then (
                color: '#fff'
                weight: 2
                opacity: 0.5
                fillOpacity: 0.6 )
              when 'regional' then weight: 0, opacity: 0.6

        $scope.$watch 'selected', (layer, oldLayer) ->
          if layer != null
            if $scope.viewMode == 'schools'
              setSchool layer


        setSchool = (layer) ->
          latlng = [layer.feature.latitude, layer.feature.longitude]
          markSchool latlng
          leafletData.getMap(mapId).then (map) ->
            setMapView latlng, (Math.max 9, map.getZoom())
          if $scope.schoolType == 'secondary'
            OpenDataApi.getRank(layer.feature)

        $scope.setSchool = (item, model, showAllSchools) ->
            unless $scope.selectedSchool? and item._id == $scope.selectedSchool._id
              if($scope.schoolType == 'secondary')
                OpenDataApi.getRank(item, $scope.selectedYear).success (response) ->
                  row = response.result.records[0]
                  if(response?)
                    $scope.districtRank = {rank: row.DISTRICT_RANK_ALL, counter: row.district_schools}
                    $scope.regionRank = {rank: row.REGIONAL_RANK_ALL, counter: row.regional_schools}

            $scope.selectedSchool = item
            unless showAllSchools? and showAllSchools == false
                $scope.setViewMode 'schools'
            if item.pass_2014 < 10 && item.pass_2014 > 0
                $scope.selectedSchool.pass_by_10 = 1
            else
                $scope.selectedSchool.pass_by_10 = Math.round item.pass_2014/10
            $scope.selectedSchool.fail_by_10 = 10 - $scope.selectedSchool.pass_by_10
            OpenDataApi.getSchoolPassOverTime($scope.schoolType, $scope.rankBest, item.CODE).success (data) ->
              parseList = data.result.records.map (x) -> {key: x.YEAR_OF_RESULT, val: parseInt(x.PASS_RATE)}
              $scope.passratetime = parseList

            # TODO: cleaner way?
            # Ensure the parent div has been fully rendered
            setTimeout( () ->
              if $scope.viewMode == 'schools'
                chartSrv.drawNationalRanking item, $scope.worstSchools[0].RANK
            , 400)


        # widget local state (maybe should move to other directives)
        $scope.searchText = "dar"
        $scope.schoolsChoices = []

        # controller constants
        mapId = 'map'

        # other global-ish stuff
        schoolMarker = null

        ptMin = 0
        ptMax = 150
        $scope.passRange =
            min: 0
            max: 100
        $scope.ptRange =
            min: ptMin
            max: ptMax
        $scope.filterPassRate = {
          range: {
              min: 0,
              max: 100
          },
          minValue: 0,
          maxValue: 100
        };
        $scope.filterPupilRatio = {
          range: {
              min: 0,
              max: 10
          },
          minValue: 0,
          maxValue: 10
        };
        $scope.moreThan40 = $routeParams.morethan40
        if $routeParams.type isnt 'primary' and $routeParams.type isnt 'secondary'
          $timeout -> $location.path '/'

        leafletData.getMap(mapId).then (map) ->
          # initialize the map view
          map.setView [-7.199, 34.1894], 6
          # add the basemap
          layersSrv.addTileLayer 'gray', mapId, '//{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png'
          # set up the initial view
          $scope.setViewMode 'schools'
          $scope.setYear 2014


        attachLayerEvents = (layer) ->
          layer.on 'mouseover', -> $scope.$apply ->
            $scope.hover layer
          layer.on 'mouseout', -> $scope.$apply ->
            $scope.unHover()
          layer.on 'click', -> $scope.$apply ->
            $scope.select layer

        mapLayerCreators =
          schools: ->
            getData = -> $q (resolve, reject) ->
              WorldBankApi.getSchools $scope.schoolType, $scope.moreThan40
                .success (data) ->
                  resolve data.rows.map (school) -> [
                    school.latitude,
                    school.longitude,
                    school,
                  ]
                .error reject
            options =
              className: 'school-location'
              radius: 8
              onEachFeature: (data, layer) ->
                layer.feature = data
                colorPin layer
                attachLayerEvents layer
            layersSrv.addFastCircles "schools-#{$scope.schoolType}", mapId,
              getData: getData
              options: options

          regional: ->
            getData = -> $q (resolve, reject) ->
              WorldBankApi.getDistricts $scope.schoolType
                .success (data) ->
                  resolve
                    type: 'FeatureCollection'
                    features: data.rows.map (district) ->
                      type: 'Feature'
                      geometry: JSON.parse district.geojson
                      properties: angular.extend district, geojson: null
                .error reject
            options =
              onEachFeature: (feature, layer) -> attachLayerEvents layer
            layersSrv.addGeojsonLayer "regions-#{$scope.schoolType}", mapId,
              getData: getData
              options: options


        colorPin = (l) ->
          v = switch
            when $scope.visMode == 'passrate' then l.feature.passrate
            when $scope.visMode == 'ptratio' then l.feature.pt_ratio
          l.setStyle colorSrv.pinStyle v, $scope.visMode

        colorPins = ->
          if $scope.viewMode != 'schools'
            console.error 'colorPins should only be called when viewMode is "schools"'
            return
          _(currentLayer._group.getLayers()).each colorPin

        groupByDistrict = (rows) ->
          districts = {}
          for row in rows
            unless districts[row.district]
              districts[row.district] = {pt_ratio: [], pass_2014: []}
            for prop in ['pt_ratio', 'pass_2014']
              districts[row.district][prop].push(row[prop])
          districts

        average = (nums) -> (nums.reduce (a, b) -> a + b) / nums.length

        colorRegions = ->
          if $scope.viewMode != 'regional'
            console.error 'colorRegions should only be called when viewMode is "regional"'
            return
          WorldBankApi.getSchools($scope.schoolType).success (data) ->
            byRegion = groupByDistrict data.rows
            _(currentLayer.getLayers()).each (l) ->
              regionData = byRegion[l.feature.properties.name]
              if not regionData
                v = null
              else if $scope.visMode == 'passrate'
                v = average(regionData.pass_2014)
              else
                v = average(regionData.pt_ratio)
              l.setStyle colorSrv.areaStyle v, $scope.visMode

        markSchool = (latlng) ->
          unless schoolMarker?
            icon = layersSrv.awesomeIcon markerColor: 'blue', icon: 'map-marker'
            schoolMarker = layersSrv.marker 'school-marker', mapId,
              latlng: latlng
              options: icon: icon

          schoolMarker.then (marker) ->
            marker.setLatLng latlng

        setMapView = (latlng, zoom, view) ->
            if view?
                $scope.setViewMode view
            unless zoom?
                zoom = 9
            leafletData.getMap(mapId).then (map) ->
                map.setView latlng, zoom

        updateMap = () ->
          if $scope.viewMode != 'district'
            # Include schools with no pt_ratio are also shown when the pt limits in extremeties
            if $scope.ptRange.min == ptMin and $scope.ptRange.max == ptMax
                WorldBankApi.updateLayers(layers, $scope.schoolType, $scope.passRange)
            else
                WorldBankApi.updateLayersPt(layers, $scope.schoolType, $scope.passRange, $scope.ptRange)

        $scope.updateMap = _.debounce(updateMap, 500)

        $scope.$on 'filtersToggle', (event, opts) ->
          $scope.filtersHeight = opts.height

        $scope.getSchoolsChoices = (query) ->
          if query?
            OpenDataApi.getSchoolsChoices($scope.schoolType, $scope.rankBest, query, $scope.selectedYear).success (data) ->
              $scope.searchText = query
              $scope.schoolsChoices = data.result.records

        $scope.$watch 'passRange', ((newVal, oldVal) ->
            unless _.isEqual(newVal, oldVal)
                $scope.updateMap()
            return
        ), true

        $scope.$watch 'ptRange', ((newVal, oldVal) ->
            unless _.isEqual(newVal, oldVal)
                $scope.updateMap()
            return
        ), true

        $scope.getTimes = (n) ->
            new Array(n)

        $scope.anchorScroll = () ->
            $anchorScroll()

        WorldBankApi.getTopDistricts({educationLevel: $scope.schoolType, metric: 'avg_pass_rate', order: 'DESC'}).then (result) ->
          $scope.bpdistrics = result.data.rows
        WorldBankApi.getTopDistricts({educationLevel: $scope.schoolType, metric: 'avg_pass_rate', order: 'ASC'}).then (result) ->
          $scope.wpdistrics = result.data.rows
        WorldBankApi.getTopDistricts({educationLevel: $scope.schoolType, metric: 'change', order: 'DESC'}).then (result) ->
          $scope.midistrics = result.data.rows
        WorldBankApi.getTopDistricts({educationLevel: $scope.schoolType, metric: 'change', order: 'ASC'}).then (result) ->
          $scope.lidistrics = result.data.rows
        MetricsSrv.getPupilTeacherRatio({level: $scope.schoolType}).then (data) ->
          $scope.pupilTeacherRatio = data.rate

        updateDashboard = () ->
          OpenDataApi.getBestSchool($scope.schoolType, $scope.rankBest, $scope.moreThan40, $scope.selectedYear).success (data) ->
            $scope.bestSchools = data.result.records

          OpenDataApi.getWorstSchool($scope.schoolType, $scope.rankBest, $scope.moreThan40, $scope.selectedYear).success (data) ->
            $scope.worstSchools = data.result.records

          OpenDataApi.mostImprovedSchools($scope.schoolType, $scope.rankBest, $scope.moreThan40, $scope.selectedYear).success (data) ->
            $scope.mostImprovedSchools = data.result.records

          OpenDataApi.leastImprovedSchools($scope.schoolType, $scope.rankBest, $scope.moreThan40, $scope.selectedYear).success (data) ->
            $scope.leastImprovedSchools = data.result.records

          OpenDataApi.getGlobalPassrate($scope.schoolType, $scope.rankBest, $scope.moreThan40, $scope.selectedYear).success (data) ->
            $scope.passrate = parseFloat data.result.records[0].avg

          OpenDataApi.getGlobalChange($scope.schoolType, $scope.rankBest, $scope.moreThan40, $scope.selectedYear).success (data) ->
            records = data.result.records
            $scope.passRateChange = if(records.length == 2) then parseInt(records[1].avg - records[0].avg) else 0

          OpenDataApi.getPassOverTime($scope.schoolType, $scope.rankBest, $scope.moreThan40).success (data) ->
            parseList = data.result.records.map (x) -> {key: x.YEAR_OF_RESULT, val: parseInt(x.avg)}
            $scope.globalpassratetime = parseList

        $scope.$watch '[rankBest, moreThan40, selectedYear]', updateDashboard
        $scope.rankBest = 'performance' if (!$scope.rankBest? and $scope.schoolType is 'primary')
]
