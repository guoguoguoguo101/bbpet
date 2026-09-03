import { useState } from 'react'
import { CITIES } from '../../shared/cities'
import { DEFAULT_COLORS, SPECIES_LABELS, type PetProfile, type Species } from '../../shared/types'
import { extractPalette, fileToDataUrl } from '../pet/colors'
import { PixelPet } from '../pet/PixelPet'

const SPECIES: Species[] = ['cat', 'dog', 'rabbit', 'bird', 'hamster', 'blob']

interface WizardProps {
  initial: PetProfile
  cityId: string
  onCityChange: (cityId: string) => void
  onDone: (pet: PetProfile) => void
}

export function Wizard({ initial, cityId, onCityChange, onDone }: WizardProps) {
  const [pet, setPet] = useState<PetProfile>(initial)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const applyPhoto = async (file?: File) => {
    if (!file) return
    setBusy(true)
    setError('')
    try {
      const [colors, photoDataUrl] = await Promise.all([extractPalette(file, pet.species), fileToDataUrl(file)])
      setPet((current) => ({ ...current, colors, photoDataUrl }))
    } catch {
      setError('这张照片有点调皮，换一张再试试。')
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="panel wizard-panel">
      <header className="panel-head">
        <strong>迎接你的桌宠</strong>
      </header>
      <p className="hint">上传一张宠物照片，我会提取主色，画成角落里的像素小伙伴。</p>
      <label className="upload">
        <input
          type="file"
          accept="image/*"
          onChange={(event) => void applyPhoto(event.target.files?.[0])}
        />
        {pet.photoDataUrl ? '换一张照片' : '上传宠物照片'}
      </label>
      <div className="preview-row">
        <PixelPet species={pet.species} colors={pet.colors} pose="idle" pixelSize={4} />
        {pet.photoDataUrl && <img className="photo-chip" src={pet.photoDataUrl} alt="原图" />}
      </div>
      <div className="species-grid">
        {SPECIES.map((species) => (
          <button
            key={species}
            type="button"
            className={pet.species === species ? 'chip active' : 'chip'}
            onClick={() =>
              setPet((current) => ({
                ...current,
                species,
                colors: current.photoDataUrl ? current.colors : DEFAULT_COLORS[species],
              }))
            }
          >
            {SPECIES_LABELS[species]}
          </button>
        ))}
      </div>
      <label className="field">
        <span>名字</span>
        <input
          value={pet.name}
          maxLength={12}
          onChange={(event) => setPet((current) => ({ ...current, name: event.target.value }))}
        />
      </label>
      <label className="field">
        <span>城市</span>
        <select value={cityId} onChange={(event) => onCityChange(event.target.value)}>
          {CITIES.map((city) => (
            <option key={city.id} value={city.id}>
              {city.name}
            </option>
          ))}
        </select>
      </label>
      {error && <p className="error">{error}</p>}
      <button
        type="button"
        className="primary"
        disabled={busy || !pet.name.trim()}
        onClick={() => onDone({ ...pet, name: pet.name.trim() })}
      >
        {busy ? '正在调色...' : '开始同居'}
      </button>
    </section>
  )
}
