import { useMemo } from 'react'
import type { WeatherFx, WeatherInfo } from '../../shared/types'

function bits(fx: WeatherFx, count: number) {
  return Array.from({ length: count }, (_, i) => ({
    i,
    left: 8 + ((i * 37) % 84),
    delay: (i * 0.23) % 1.6,
    dur: 1.1 + (i % 5) * 0.18,
  }))
}

const STARS = [
  { left: 2, top: 0, size: 'lg', delay: 0, dur: 0.9 },
  { left: 20, top: 8, size: 'sm', delay: 0.25, dur: 1.35 },
  { left: 42, top: 2, size: 'md', delay: 0.55, dur: 1.1 },
  { left: 68, top: 10, size: 'sm', delay: 0.1, dur: 0.8 },
  { left: 86, top: 1, size: 'lg', delay: 0.7, dur: 1.2 },
  { left: 10, top: 18, size: 'sm', delay: 0.4, dur: 1.5 },
  { left: 58, top: 16, size: 'md', delay: 0.9, dur: 0.95 },
  { left: 78, top: 20, size: 'sm', delay: 1.15, dur: 1.4 },
]

export function WeatherDress({ weather }: { weather: WeatherInfo }) {
  const rain = useMemo(() => (weather.fx.includes('rain') ? bits('rain', weather.fx.includes('storm') ? 14 : 9) : []), [weather.fx])
  const snow = useMemo(() => (weather.fx.includes('snow') ? bits('snow', 8) : []), [weather.fx])
  const spark = useMemo(() => (weather.fx.includes('sun') ? bits('sun', 5) : []), [weather.fx])
  const night = weather.fx.includes('stars')

  return (
    <>
      <div className={`weather-fx${weather.fx.includes('fog') ? ' fog' : ''}${weather.fx.includes('storm') ? ' storm' : ''}`}>
        {rain.map((drop) => (
          <span
            key={`r${drop.i}`}
            className="wx-rain"
            style={{ left: `${drop.left}%`, animationDelay: `${drop.delay}s`, animationDuration: `${drop.dur}s` }}
          />
        ))}
        {snow.map((flake) => (
          <span
            key={`s${flake.i}`}
            className="wx-snow"
            style={{ left: `${flake.left}%`, animationDelay: `${flake.delay}s`, animationDuration: `${1.8 + flake.dur}s` }}
          />
        ))}
        {spark.map((dot) => (
          <span
            key={`p${dot.i}`}
            className="wx-sun"
            style={{ left: `${dot.left}%`, top: `${8 + (dot.i % 3) * 10}px`, animationDelay: `${dot.delay}s` }}
          />
        ))}
      </div>
      {night && (
        <div className="wx-sky">
          <div className="wx-moon" title="月亮" />
          {STARS.map((star, i) => (
            <span
              key={`st${i}`}
              className={`wx-star wx-star-${star.size}`}
              style={{
                left: `${star.left}%`,
                top: `${star.top}px`,
                animationDelay: `${star.delay}s`,
                animationDuration: `${star.dur}s`,
              }}
            />
          ))}
        </div>
      )}
      {weather.fx.includes('cloud') && (
        <div className={`wx-clouds${weather.code === 3 ? ' heavy' : ''}`}>
          <span className="wx-cloud a" />
          <span className="wx-cloud b" />
          {weather.code === 3 && <span className="wx-cloud c" />}
        </div>
      )}
      {weather.gear.includes('juice') && <div className="wx-juice" />}
      {weather.gear.includes('umbrella') && <div className="wx-umbrella" title="伞" />}
      {weather.gear.includes('snowman') && (
        <div className="wx-snowman" title="小雪人">
          <span className="wx-snowman-arm left" />
          <span className="wx-snowman-arm right" />
          <span className="wx-snowman-hat" />
          <span className="wx-snowman-head" />
          <span className="wx-snowman-body" />
        </div>
      )}
    </>
  )
}
