app = angular.module 'zauth', []

app.config [
	'$routeProvider'
	'$httpProvider'

	($routeProvider, $httpProvider) ->
		$routeProvider.when '/auth/login', {
			templateUrl: '/partials/auth/login.html'
		}

		$httpProvider.interceptors.push 'AuthInterceptor'
]

app.run [
	'$rootScope'
	'$location'
	'AuthService'
	'$window'
	'$http'

	($rootScope, $location, AuthService, $window, $http) ->
		$rootScope.reqs = []

		nextPath = "/"
		$rootScope.$on 'unauthorised-api', (event, { page }) ->
			return if page is '/auth/login'

			nextPath := page

			$location.path '/auth/login'

		$rootScope.$on '$routeChangeStart', (event, next, current) ->
			path = $location.path!

			return if path is '/404'
			return if AuthService.isLoggedIn!
			return if next?$$route?originalPath is '/auth/login'

			if current?$$route?originalPath is not '/auth/login'
				nextPath := path

			#console.log "Redirect to login from " + path
			event.preventDefault!

			$location.path '/auth/login'

		$rootScope.$on 'authSuccess', (event, auth) ->
			#HeartBeat.start!

			for req in $rootScope.reqs
				$http req.config .then req.defer.resolve, req.defer.reject

			$rootScope.reqs = []
			if auth.isNew or $location.path! is not nextPath
				$location.path nextPath

		$rootScope.$on 'logout', (event) ->
			#HeartBeat.stop!
			# this causes a full reload, clearing state.
			$window.location.href = ""
]

app.factory 'AuthService', [
	'$http'
	'$q'
	'$rootScope'

	($http, $q, $rootScope) ->
		authed = false

		isLoggedIn: -> authed

		login: (username, password) ->
			defer = $q.defer!
			# Do this over https
			$http.post '/api/auth/login', {username, password}
				do
					(data, status, headers, conf) <- ..success
					return defer.reject! if status is not 200

					key = data['api-key']
					authed := true

					$http.defaults.headers.common['api-key'] = key

					$rootScope.$broadcast \authSuccess, { key }

					defer.resolve!
				do
					(data, status, headers, conf) <- ..error
					authed := false
					defer.reject!

			defer.promise

		logout: ->
			done = ->
				authed := false
				delete $http.defaults.headers.common['api-key']

			$http.post "/api/auth/logout"
				..success done
				..error done
]

app.factory 'AuthInterceptor', [
	'$q'
	'$rootScope'
	'$location'

	($q, $rootScope, $location) ->
		responseError: ({config, data, headers, status}:res) ->
			return res if status is not 401
			return res if config.url.match /\/api\/auth/

			defer = $q.defer!

			req = { defer, config }

			$rootScope.reqs.push req

			$rootScope.$broadcast 'unauthorised-api', { page: $location.path! }

			return defer.promise
]

app.controller 'AuthCtrl', [
	'$scope'
	'AuthService'

	($scope, AuthService) ->
		$scope.auth =
			error: false

		$scope.login = (auth) ->
			AuthService.login auth.user, auth.passw .then ->, -> auth.error = true
]