import { useEffect, useState } from 'react'
import type { FlyerPlay } from '../../shared/homeActions'
import { PixelPet } from '../pet/PixelPet'

export function FlyerApp() {
  const [payload, setPayload] = useState<FlyerPlay | null>(null)

  useEffect(() => {
    document.documentElement.classList.add('flyer-host')
    document.body.classList.add('flyer-host')
    return window.bbpet.onShowFlyer((next) => setPayload(next))
  }, [])

  if (!payload) return null

  return (
    <div className="flyer-spin">
      <PixelPet
        species={payload.species}
        colors={payload.colors}
        pose={payload.pose || 'peek'}
        gears={payload.gears ?? []}
      />
    </div>
  )
}
