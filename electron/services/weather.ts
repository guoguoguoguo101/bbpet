import type { WeatherInfo } from '../../shared/types'

const WEATHER_MAP: Record<number, { description: string; emoji: string }> = {
  0: { description: '晴朗', emoji: '☀️' },
  1: { description: '大部晴朗', emoji: '🌤️' },
  2: { description: '多云', emoji: '⛅' },
  3: { description: '阴天', emoji: '☁️' },
  45: { description: '有雾', emoji: '🌫️' },
  48: { description: '雾凇', emoji: '🌫️' },
  51: { description: '小毛毛雨', emoji: '🌦️' },
  53: { description: '毛毛雨', emoji: '🌦️' },
  55: { description: '大毛毛雨', emoji: '🌧️' },
  61: { description: '小雨', emoji: '🌧️' },
  63: { description: '中雨', emoji: '🌧️' },
  65: { description: '大雨', emoji: '🌧️' },
  71: { description: '小雪', emoji: '🌨️' },
  73: { description: '中雪', emoji: '🌨️' },
  75: { description: '大雪', emoji: '❄️' },
  80: { description: '阵雨', emoji: '🌦️' },
  81: { description: '强阵雨', emoji: '🌧️' },
  82: { description: '暴雨', emoji: '⛈️' },
  95: { description: '雷阵雨', emoji: '⛈️' },
  96: { description: '雷阵雨带冰雹', emoji: '⛈️' },
  99: { description: '强雷暴', emoji: '⛈️' },
}

function lookupWeather(code: number) {
  return WEATHER_MAP[code] ?? { description: '天气微妙', emoji: '🌈' }
}

export async function fetchWeather(cityName: string, latitude: number, longitude: number): Promise<WeatherInfo> {
  const url = new URL('https://api.open-meteo.com/v1/forecast')
  url.searchParams.set('latitude', String(latitude))
  url.searchParams.set('longitude', String(longitude))
  url.searchParams.set('current', 'temperature_2m,weather_code')
  url.searchParams.set('timezone', 'Asia/Shanghai')

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), 12000)
  try {
    const response = await fetch(url, { signal: controller.signal })
    if (!response.ok) throw new Error(`weather ${response.status}`)
    const data = (await response.json()) as {
      current?: { temperature_2m?: number; weather_code?: number }
    }
    const temperature = Math.round(data.current?.temperature_2m ?? 0)
    const mapped = lookupWeather(data.current?.weather_code ?? -1)
    return { cityName, temperature, ...mapped }
  } finally {
    clearTimeout(timer)
  }
}

export function formatWeatherLine(info: WeatherInfo) {
  return `${info.cityName} ${info.emoji} ${info.description}，${info.temperature}°C`
}
