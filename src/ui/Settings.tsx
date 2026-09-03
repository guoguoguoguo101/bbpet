import { useEffect, useState } from 'react'
import { CITIES } from '../../shared/cities'
import { DEFAULT_COLORS, SPECIES_LABELS, type AppSettings, type PetProfile, type Species } from '../../shared/types'
import { extractPalette, fileToDataUrl } from '../pet/colors'

const SPECIES: Species[] = ['cat', 'dog', 'rabbit', 'bird', 'hamster', 'blob']

interface SettingsProps {
  pet: PetProfile
  settings: AppSettings
  onSavePet: (pet: PetProfile) => Promise<void>
  onSaveSettings: (settings: AppSettings) => Promise<void>
  onClose: () => void
}

export function Settings({ pet, settings, onSavePet, onSaveSettings, onClose }: SettingsProps) {
  const [draftPet, setDraftPet] = useState(pet)
  const [draft, setDraft] = useState(settings)
  const [busy, setBusy] = useState(false)
  const [hostInfo, setHostInfo] = useState<{ hosting: boolean; error: string; urls: string[] } | null>(null)

  useEffect(() => {
    void window.bbpet.roomHostInfo().then(setHostInfo)
  }, [])

  const applyPhoto = async (file?: File) => {
    if (!file) return
    const [colors, photoDataUrl] = await Promise.all([extractPalette(file, draftPet.species), fileToDataUrl(file)])
    setDraftPet((current) => ({ ...current, colors, photoDataUrl }))
  }

  const save = async () => {
    setBusy(true)
    try {
      const city = CITIES.find((item) => item.id === draft.cityId) ?? CITIES[0]
      await onSavePet({ ...draftPet, name: draftPet.name.trim() || pet.name })
      await onSaveSettings({
        ...draft,
        cityName: city.name,
        latitude: city.latitude,
        longitude: city.longitude,
        pushIntervalMin: Math.max(5, Number(draft.pushIntervalMin) || 30),
        roomUrl: (draft.roomUrl || '').trim() || 'ws://127.0.0.1:18765',
        hostRoom: Boolean(draft.hostRoom),
        worldWidth: draft.worldWidth || 820,
        worldHeight: draft.worldHeight || 560,
      })
      setHostInfo(await window.bbpet.roomHostInfo())
      onClose()
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="panel settings-panel">
      <header className="panel-head">
        <strong>设置</strong>
        <button type="button" className="ghost" onClick={onClose}>
          关闭
        </button>
      </header>
      <label className="field">
        <span>名字</span>
        <input value={draftPet.name} maxLength={12} onChange={(event) => setDraftPet({ ...draftPet, name: event.target.value })} />
      </label>
      <div className="species-grid compact">
        {SPECIES.map((species) => (
          <button
            key={species}
            type="button"
            className={draftPet.species === species ? 'chip active' : 'chip'}
            onClick={() =>
              setDraftPet((current) => ({
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
      <label className="upload">
        <input type="file" accept="image/*" onChange={(event) => void applyPhoto(event.target.files?.[0])} />
        重新上传照片
      </label>
      <label className="field">
        <span>城市</span>
        <select value={draft.cityId} onChange={(event) => setDraft({ ...draft, cityId: event.target.value })}>
          {CITIES.map((city) => (
            <option key={city.id} value={city.id}>
              {city.name}
            </option>
          ))}
        </select>
      </label>
      <label className="field">
        <span>推送间隔（分钟）</span>
        <input
          type="number"
          min={5}
          max={180}
          value={draft.pushIntervalMin}
          onChange={(event) => setDraft({ ...draft, pushIntervalMin: Number(event.target.value) })}
        />
      </label>
      <label className="field">
        <span>学校服务器</span>
        <input
          value={draft.roomUrl ?? ''}
          placeholder="ws://127.0.0.1:18765"
          onChange={(event) => setDraft({ ...draft, roomUrl: event.target.value })}
        />
      </label>
      <label className="host-row">
        <input
          type="checkbox"
          checked={Boolean(draft.hostRoom)}
          onChange={(event) =>
            setDraft({
              ...draft,
              hostRoom: event.target.checked,
              roomUrl: event.target.checked && !(draft.roomUrl || '').trim() ? 'ws://127.0.0.1:18765' : draft.roomUrl,
            })
          }
        />
        <span>我来当校长（本机开房，同事填下面的内网地址）</span>
      </label>
      {hostInfo?.hosting && (
        <p className="hint">校长室已开：{hostInfo.urls.filter((url) => !url.includes('127.0.0.1')).join(' 或 ') || hostInfo.urls[0]}</p>
      )}
      {hostInfo?.error && <p className="error">{hostInfo.error}</p>}
      <label className="field">
        <span>API Base URL</span>
        <input
          value={draft.apiBaseUrl}
          placeholder="https://openrouter.ai/api/v1"
          onChange={(event) => setDraft({ ...draft, apiBaseUrl: event.target.value })}
        />
      </label>
      <label className="field">
        <span>API Key（可填自己的）</span>
        <input
          type="password"
          value={draft.apiKey}
          placeholder="sk-or-v1-..."
          onChange={(event) => setDraft({ ...draft, apiKey: event.target.value })}
        />
      </label>
      <label className="field">
        <span>模型</span>
        <input value={draft.model} onChange={(event) => setDraft({ ...draft, model: event.target.value })} />
      </label>
      <label className="field">
        <span>回退模型</span>
        <input value={draft.fallbackModel} onChange={(event) => setDraft({ ...draft, fallbackModel: event.target.value })} />
      </label>
      <button type="button" className="primary" disabled={busy} onClick={() => void save()}>
        {busy ? '保存中...' : '保存'}
      </button>
    </section>
  )
}
