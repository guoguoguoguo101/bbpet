import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'
import { DEFAULT_COLORS, type PetColors, type Species } from '../shared/types'

export interface FriendRecord {
  name: string
  species: Species
  colors: PetColors
  friends: string[]
  incoming: string[]
}

interface FileShape {
  users: Record<string, FriendRecord>
}

export function createFriendsStore(file: string) {
  let data: FileShape = { users: {} }
  let timer: ReturnType<typeof setTimeout> | null = null

  const load = () => {
    try {
      if (!existsSync(file)) return
      const raw = JSON.parse(readFileSync(file, 'utf8')) as FileShape
      if (raw && typeof raw.users === 'object' && raw.users) data = { users: raw.users }
    } catch {
      data = { users: {} }
    }
  }

  const flush = () => {
    mkdirSync(dirname(file), { recursive: true })
    writeFileSync(file, JSON.stringify(data), 'utf8')
  }

  const save = () => {
    if (timer) clearTimeout(timer)
    timer = setTimeout(flush, 200)
  }

  const ensure = (id: string): FriendRecord => {
    const current = data.users[id]
    if (current) return current
    const created: FriendRecord = {
      name: '桌宠',
      species: 'blob',
      colors: DEFAULT_COLORS.blob,
      friends: [],
      incoming: [],
    }
    data.users[id] = created
    return created
  }

  load()

  const isFriend = (a: string, b: string) =>
    Boolean(data.users[a]?.friends.includes(b) && data.users[b]?.friends.includes(a))

  return {
    upsert(id: string, profile: { name: string; species: Species; colors: PetColors }) {
      const rec = ensure(id)
      rec.name = profile.name
      rec.species = profile.species
      rec.colors = profile.colors
      save()
      return rec
    },
    get(id: string) {
      return data.users[id] ?? null
    },
    isFriend,
    request(from: string, to: string): 'accepted' | 'pending' | 'same' | 'already' {
      if (from === to) return 'same'
      if (isFriend(from, to)) return 'already'
      const a = ensure(from)
      const b = ensure(to)
      if (a.incoming.includes(to)) {
        a.incoming = a.incoming.filter((id) => id !== to)
        b.incoming = b.incoming.filter((id) => id !== from)
        if (!a.friends.includes(to)) a.friends.push(to)
        if (!b.friends.includes(from)) b.friends.push(from)
        save()
        return 'accepted'
      }
      if (b.incoming.includes(from)) return 'pending'
      b.incoming.push(from)
      save()
      return 'pending'
    },
    accept(me: string, from: string) {
      const a = ensure(me)
      const b = ensure(from)
      if (!a.incoming.includes(from)) return false
      a.incoming = a.incoming.filter((id) => id !== from)
      b.incoming = b.incoming.filter((id) => id !== me)
      if (!a.friends.includes(from)) a.friends.push(from)
      if (!b.friends.includes(me)) b.friends.push(me)
      save()
      return true
    },
    decline(me: string, from: string) {
      const a = ensure(me)
      if (!a.incoming.includes(from)) return false
      a.incoming = a.incoming.filter((id) => id !== from)
      save()
      return true
    },
  }
}
