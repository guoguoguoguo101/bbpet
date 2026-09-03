import type { WeatherFx, WeatherGear, WeatherInfo } from '../../shared/types'
import { pickLine, WEATHER_LINES } from '../../shared/weatherLines'

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
  56: { description: '冻毛毛雨', emoji: '🌧️' },
  57: { description: '强冻毛毛雨', emoji: '🌧️' },
  61: { description: '小雨', emoji: '🌧️' },
  63: { description: '中雨', emoji: '🌧️' },
  65: { description: '大雨', emoji: '🌧️' },
  66: { description: '冻雨', emoji: '🌧️' },
  67: { description: '强冻雨', emoji: '🌧️' },
  71: { description: '小雪', emoji: '🌨️' },
  73: { description: '中雪', emoji: '🌨️' },
  75: { description: '大雪', emoji: '❄️' },
  77: { description: '雪粒', emoji: '🌨️' },
  80: { description: '阵雨', emoji: '🌦️' },
  81: { description: '强阵雨', emoji: '🌧️' },
  82: { description: '暴雨', emoji: '⛈️' },
  85: { description: '小阵雪', emoji: '🌨️' },
  86: { description: '强阵雪', emoji: '❄️' },
  95: { description: '雷阵雨', emoji: '⛈️' },
  96: { description: '雷阵雨带冰雹', emoji: '⛈️' },
  99: { description: '强雷暴', emoji: '⛈️' },
}

function lookupWeather(code: number) {
  return WEATHER_MAP[code] ?? { description: '天气微妙', emoji: '🌈' }
}

function unique<T>(items: T[]) {
  return [...new Set(items)]
}

function has(code: number, ids: number[]) {
  return ids.includes(code)
}

export function dressFor(code: number, temperature: number, isDay: boolean, wind: number) {
  if (!isDay) {
    return { gear: [] as WeatherGear[], fx: ['stars'] as WeatherFx[], dressLine: pickLine(WEATHER_LINES.night) }
  }

  const gear: WeatherGear[] = []
  const fx: WeatherFx[] = []
  let dressLine = pickLine(WEATHER_LINES.fallback)

  const storm = code >= 95 || code === 82 || code === 99
  const snow = has(code, [71, 73, 75, 77, 85, 86])
  const rain = storm || has(code, [55, 61, 63, 65, 66, 67, 80, 81, 82])
  const drizzle = has(code, [51, 53, 56, 57])
  const fog = code === 45 || code === 48
  const clear = code === 0 || code === 1
  const partly = code === 2
  const overcast = code === 3

  if (storm) {
    gear.push('raincoat', 'umbrella')
    fx.push('rain', 'storm')
    dressLine = pickLine(WEATHER_LINES.storm)
  } else if (snow) {
    gear.push('beanie', 'scarf', 'snowman')
    fx.push('snow')
    dressLine = pickLine(WEATHER_LINES.snow)
  } else if (rain) {
    gear.push('raincoat', 'umbrella')
    fx.push('rain')
    dressLine = pickLine(WEATHER_LINES.rain)
  } else if (drizzle) {
    gear.push('umbrella')
    fx.push('rain')
    dressLine = pickLine(WEATHER_LINES.drizzle)
  } else if (fog) {
    fx.push('fog')
    dressLine = pickLine(WEATHER_LINES.fog)
  } else if (clear) {
    gear.push('shades', 'juice')
    fx.push('sun')
    dressLine = pickLine(temperature >= 30 ? WEATHER_LINES.sunHot : WEATHER_LINES.sun)
  } else if (partly) {
    fx.push('cloud', 'sun')
    if (temperature >= 30) {
      gear.push('shades', 'juice')
      dressLine = pickLine(WEATHER_LINES.sunHot)
    } else {
      dressLine = pickLine(WEATHER_LINES.partly)
    }
  } else if (overcast) {
    fx.push('cloud')
    dressLine = pickLine(WEATHER_LINES.overcast)
  }

  if (temperature <= 6 && !rain && !drizzle && !storm) {
    if (!gear.includes('scarf')) gear.push('scarf')
    if (!gear.includes('beanie')) gear.push('beanie')
    if (!snow) dressLine = pickLine(WEATHER_LINES.cold)
  }

  if (temperature >= 30 && (rain || drizzle) && !gear.includes('raincoat')) {
    gear.push('raincoat')
  }

  if (wind >= 28 && !storm) {
    fx.push('wind')
    dressLine = pickLine(WEATHER_LINES.wind)
  }

  if (!gear.length && !fx.length) {
    if (temperature >= 28) {
      gear.push('shades', 'juice')
      fx.push('sun')
      dressLine = pickLine(WEATHER_LINES.sunHot)
    } else if (temperature <= 6) {
      gear.push('scarf', 'beanie')
      dressLine = pickLine(WEATHER_LINES.cold)
    } else {
      fx.push('cloud')
      dressLine = pickLine(WEATHER_LINES.fallback)
    }
  }

  return { gear: unique(gear), fx: unique(fx), dressLine }
}

export async function fetchWeather(cityName: string, latitude: number, longitude: number): Promise<WeatherInfo> {
  const url = new URL('https://api.open-meteo.com/v1/forecast')
  url.searchParams.set('latitude', String(latitude))
  url.searchParams.set('longitude', String(longitude))
  url.searchParams.set('current', 'temperature_2m,weather_code,is_day,wind_speed_10m')
  url.searchParams.set('timezone', 'Asia/Shanghai')

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), 12000)
  try {
    const response = await fetch(url, { signal: controller.signal })
    if (!response.ok) throw new Error(`weather ${response.status}`)
    const data = (await response.json()) as {
      current?: {
        temperature_2m?: number
        weather_code?: number
        is_day?: number
        wind_speed_10m?: number
      }
    }
    const temperature = Math.round(data.current?.temperature_2m ?? 0)
    const code = data.current?.weather_code ?? -1
    const isDay = data.current?.is_day !== 0
    const wind = Number(data.current?.wind_speed_10m ?? 0)
    const mapped = lookupWeather(code)
    const dressed = dressFor(code, temperature, isDay, wind)
    return {
      cityName,
      temperature,
      code,
      isDay,
      wind,
      ...mapped,
      ...dressed,
    }
  } finally {
    clearTimeout(timer)
  }
}

export function formatWeatherLine(info: WeatherInfo) {
  return `${info.cityName} ${info.emoji} ${info.description}，${info.temperature}°C`
}
