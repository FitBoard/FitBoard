angular.module('myApp')
	.controller('UserCtrl', ['$scope',function($scope) {
	'use strict';

	$scope.athletes = [
		{
					name: 'Michal Dovrtel',
					sex: 'male',
					category: 'elite',
					gym: 'independent2',
					photo: 'img/profile.jpg',
					score: 125,
					age: '24',
					height: '175 cm',
					weight: '80 kg',
					yInC: '5y',
					cj: '90 kg',
					snatch: '75 kg',
					deadlift: '150 kg',
					frontSquat: '150 kg',
					backSquat: '160 kg',
					fran: '3:14',
					helen: '132',
					grace: '2:15',
					sprint: '1:30',
					row: '4:00'
				}];
}]);