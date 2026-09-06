class_name WeatherCities
extends RefCounted

# Source: shared/cities.ts

const CITIES: Array = [
	{"id": "beijing", "name": "北京", "latitude": 39.9042, "longitude": 116.4074},
	{"id": "shanghai", "name": "上海", "latitude": 31.2304, "longitude": 121.4737},
	{"id": "shenzhen", "name": "深圳", "latitude": 22.5431, "longitude": 114.0579},
	{"id": "hangzhou", "name": "杭州", "latitude": 30.2741, "longitude": 120.1551},
	{"id": "chengdu", "name": "成都", "latitude": 30.5728, "longitude": 104.0668},
	{"id": "guangzhou", "name": "广州", "latitude": 23.1291, "longitude": 113.2644},
	{"id": "wuhan", "name": "武汉", "latitude": 30.5928, "longitude": 114.3055},
	{"id": "nanjing", "name": "南京", "latitude": 32.0603, "longitude": 118.7969},
	{"id": "xian", "name": "西安", "latitude": 34.3416, "longitude": 108.9398},
	{"id": "suzhou", "name": "苏州", "latitude": 31.2989, "longitude": 120.5853},
	{"id": "tianjin", "name": "天津", "latitude": 39.3434, "longitude": 117.3616},
	{"id": "chongqing", "name": "重庆", "latitude": 29.4316, "longitude": 106.9123},
]

const DEFAULT_CITY: Dictionary = CITIES[0]


static func by_id(id: String) -> Dictionary:
	for city in CITIES:
		if city.id == id:
			return city.duplicate(true)
	return DEFAULT_CITY.duplicate(true)
