'use strict'

###*
 # @ngdoc service
 # @name edudashApp.OpenDataApi
 # @description
 # # OpenDataApi
 # Service in the edudashApp.
###
angular.module 'edudashAppSrv'
.service 'OpenDataApi', [
    '$http', '$resource', '$log', 'CsvParser', '$location'
    ($http, $resource, $log, CsvParser, $location) ->
      # AngularJS will instantiate a singleton by calling "new" on this function
      regexp = /.*localhost.*/ig
      corsApi = if regexp.test($location.host()) then 'https://cors-anywhere.herokuapp.com' else 'http:/'
      apiRoot = '/data.takwimu.org/api/action/'
#      apiRoot = '/tsd.dgstg.org/api/action/'
      ckanQueryURL = corsApi + apiRoot + 'datastore_search_sql'
      datasetMapping =
        primary:
          'performance': '3a77adf7-925a-4a62-8c70-5e43f022b874'
          'improvement': 'bba2cbbb-97fb-48b1-aa51-8db69279fbc5'
        secondary: '743e5062-54ae-4c96-a826-16151b6f636b'

      getdata: () ->
        $params =
          resource_id: '3221ccb4-3b75-4137-a8bd-471a436ed7a5'
        req = $resource(corsApi + apiRoot + 'datastore_search')
        req.get($params).$promise

      getDataset: (id) ->
        $params =
          resource_id: id
        req = $resource(corsApi + apiRoot + 'datastore_search')
        req.get($params).$promise

      getTable = (educationLevel, subtype) ->
        if(subtype?) then datasetMapping[educationLevel][subtype] else datasetMapping[educationLevel]

      getSql = (educationLevel, subtype, condition, sorted, limit, fields) ->
        strField = if fields? and fields.length > 0 then '"' + fields.join('","') + '"' else "*"
        table = getTable(educationLevel, subtype)
        sorted = if sorted? then "ORDER BY #{sorted}" else ''
        strLimit = if limit? then "LIMIT #{limit}" else ""
        "SELECT #{strField} FROM \"#{table}\" #{condition} #{sorted} #{strLimit}";

      getConditions = (educationLevel, moreThan40, year) ->
        condition = []
        if(educationLevel == 'secondary' and moreThan40?)
          condition.push "\"MORE_THAN_40\" = '#{moreThan40}'"
        if(year)
          condition.push '"YEAR_OF_RESULT" = ' + year
        if condition.length > 0 then "WHERE #{condition.join ' AND '}" else ""

      datasetByQuery: (query) ->
        $params =
          sql: query
        req = $resource(corsApi + apiRoot + 'datastore_search_sql')
        req.get($params).$promise

      getBestSchool: (educationLevel, subtype, moreThan40, year) ->
        $params =
          sql: getSql(educationLevel, subtype, getConditions(educationLevel, moreThan40, year), '"RANK" ASC', "20")
        $http.get(ckanQueryURL, {params: $params})

      getWorstSchool: (educationLevel, subtype, moreThan40, year) ->
        $params =
          sql: getSql(educationLevel, subtype, getConditions(educationLevel, moreThan40, year), '"RANK" DESC', "20")
        $http.get(ckanQueryURL, {params: $params})

      mostImprovedSchools: (educationLevel, subtype, moreThan40, year) ->
        $params =
          sql: getSql(educationLevel, subtype, getConditions(educationLevel, moreThan40, year), '"CHANGE_PREVIOUS_YEAR" DESC', "20")
        $http.get(ckanQueryURL, {params: $params})

      leastImprovedSchools: (educationLevel, subtype, moreThan40, year) ->
        $params =
          sql: getSql(educationLevel, subtype, getConditions(educationLevel, moreThan40, year), '"CHANGE_PREVIOUS_YEAR" ASC', "20")
        $http.get(ckanQueryURL, {params: $params})

      getGlobalPassrate: (educationLevel, subtype, moreThan40, year) ->
        $params =
          sql: "SELECT AVG(\"PASS_RATE\") FROM \"#{getTable(educationLevel, subtype)}\" #{getConditions(educationLevel, moreThan40, year)}"
        $http.get(ckanQueryURL, {params: $params})

      getGlobalChange: (educationLevel, subtype, moreThan40, year) ->
        $params =
          sql: "SELECT AVG(\"CHANGE_PREVIOUS_YEAR\") FROM \"#{getTable(educationLevel, subtype)}\" #{getConditions(educationLevel, moreThan40, year)}"
        $http.get(ckanQueryURL, {params: $params})

      getSchoolsChoices: (educationLevel, subtype, query) ->
        $params =
          sql: "SELECT * FROM \"#{getTable(educationLevel, subtype)}\" WHERE (\"NAME\" ILIKE '%#{query}%' OR \"CODE\" ILIKE '%#{query}%') LIMIT 10"
        $http.get(ckanQueryURL, {params: $params})

      getTopDistricts: (filters) ->
        # TODO implement me

      getRank: (selectedSchool, year) ->
        query = "SELECT _id,
                  \"REGIONAL_RANK_ALL\",
                  \"NATIONAL_RANK_ALL\",
                  \"DISTRICT_RANK_ALL\",
                  (SELECT COUNT(*) FROM \"743e5062-54ae-4c96-a826-16151b6f636b\" WHERE \"REGION\" = '#{selectedSchool.REGION}') as REGIONAL_SCHOOLS,
                  (SELECT COUNT(*) FROM \"743e5062-54ae-4c96-a826-16151b6f636b\" WHERE \"DISTRICT\" = '#{selectedSchool.DISTRICT}') as DISTRICT_SCHOOLS
                  FROM \"743e5062-54ae-4c96-a826-16151b6f636b\" WHERE _id = #{selectedSchool._id} AND \"YEAR_OF_RESULT\" = #{year}"
        $params =
          sql: query
        $http.get(ckanQueryURL, {params: $params})

      getPassOverTime: (educationLevel, subtype) ->
        $params =
          sql: "SELECT AVG(\"PASS_RATE\"), \"YEAR_OF_RESULT\" FROM \"#{getTable(educationLevel, subtype)}\" GROUP BY \"YEAR_OF_RESULT\" ORDER BY \"YEAR_OF_RESULT\" ASC"
        $http.get(ckanQueryURL, {params: $params})

      getSchoolPassOverTime: (educationLevel, subtype, code) ->
        $params =
          sql: "SELECT \"PASS_RATE\", \"YEAR_OF_RESULT\" FROM \"#{getTable(educationLevel, subtype)}\" WHERE \"CODE\" like '#{code}' ORDER BY \"YEAR_OF_RESULT\" ASC"
        $http.get(ckanQueryURL, {params: $params})

      getSchools: (educationLevel) ->
        fields = [
          'cartodb_id'
          'latitude'
          'longitude'
          'name'
          'region'
          'district'
          'ward'
          'pass_2012'
          'pass_2013'
          'pass_2014'
          'pt_ratio'
          'rank_2014'
        ].join ','
      # TODO implement me

      getCsv: (file) ->
        file = file.replace(/^(http|https):\/\//gm, '')
        resourceUrl = corsApi + '/' + file
        $resource(resourceUrl, {},
          getDataSet: {
            method: 'GET'
            isArray: false
            headers:
              'Content-Type': 'text/csv; charset=utf-8'
            responseType: 'text'
            transformResponse: (data, headers) ->
              #$log.debug 'csv raw data'
              result = CsvParser.parseToJson data
              #$log.debug result
              result
          }
        )

  ]
