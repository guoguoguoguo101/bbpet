import { join } from 'node:path'
import { startRoomServer } from './roomServer'
import { DEFAULT_ROOM_PORT } from '../shared/world'

const port = Number(process.env.BBPET_ROOM_PORT || DEFAULT_ROOM_PORT) || DEFAULT_ROOM_PORT
const friendsFile = process.env.BBPET_FRIENDS_FILE || join(process.cwd(), 'bbpet-friends.json')

startRoomServer(port, { friendsFile })
  .then(() => {
    console.log(`BbPet school listening on ws://0.0.0.0:${port}`)
    console.log('同事在桌宠设置里填写 ws://你的内网IP:' + port)
  })
  .catch((error: unknown) => {
    console.error(error)
    process.exit(1)
  })
