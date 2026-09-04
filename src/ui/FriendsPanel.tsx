import { useEffect, useState } from 'react'
import { canInviteFriend, isIncomingInvite, type FriendCard, type RoomView } from '../../shared/world'
import { PixelPet } from '../pet/PixelPet'

interface FriendsPanelProps {
  room: RoomView
  myId: string
  onVisit: (ownerId: string) => void
  onClose: () => void
}

export function FriendsPanel({ room, myId, onVisit, onClose }: FriendsPanelProps) {
  const [now, setNow] = useState(() => Date.now())
  const incoming = isIncomingInvite(room.game)
  const invite = incoming ? room.game : null

  useEffect(() => {
    if (!invite) return
    const id = window.setInterval(() => setNow(Date.now()), 200)
    return () => window.clearInterval(id)
  }, [invite?.id])

  const ownerAt = (card: FriendCard) => {
    if (!card.online) return '离线'
    const bits: string[] = []
    if (card.schoolPlaceId) bits.push('在学校')
    if (card.homeId === `home:${card.clientId}`) bits.push('在自己家')
    else if (card.homeId) bits.push('在别人家串门')
    return bits.join(' · ') || '在线'
  }

  const seconds = invite ? Math.max(0, Math.ceil((invite.deadlineAt - now) / 1000)) : 0

  return (
    <section className="panel friends-panel">
      <header className="panel-head">
        <strong>好友</strong>
        <button type="button" className="ghost" onClick={onClose}>
          收起
        </button>
      </header>
      {!room.connected && <p className="hint">{room.error || (room.connecting ? '正在连房主...' : '连上房主后才能加好友。')}</p>}
      {room.connected && room.error && <p className="error">{room.error}</p>}
      {room.notice && <p className="friends-notice">{room.notice}</p>}
      {invite && (
        <div className="friends-invite">
          <p>
            {invite.black.name} 邀请你下五子棋 {seconds}秒
          </p>
          <button
            type="button"
            onClick={() => window.bbpet.roomSend({ type: 'gameRespond', gameId: invite.id, accept: true })}
          >
            接受
          </button>
          <button
            type="button"
            className="ghost"
            onClick={() => window.bbpet.roomSend({ type: 'gameRespond', gameId: invite.id, accept: false })}
          >
            拒绝
          </button>
        </div>
      )}

      <div className="friends-block">
        <h3>好友列表</h3>
        {room.friends.length === 0 && <p className="hint">去学校点别的同学，点「加好友」就会出现在这里。</p>}
        {room.friends.map((card) => (
          <div key={card.clientId} className="friend-row">
            <PixelPet species={card.species} colors={card.colors} pose="idle" pixelSize={2} />
            <div className="friend-meta">
              <strong>
                {card.name}
                {card.clientId === myId ? '（我）' : ''}
              </strong>
              <small className={card.online ? 'online' : ''}>{ownerAt(card)}</small>
            </div>
            <div className="friend-actions">
              {canInviteFriend(room.game, myId, card) && (
                <button
                  type="button"
                  onClick={() => window.bbpet.roomSend({ type: 'inviteGame', targetId: card.clientId })}
                >
                  五子棋
                </button>
              )}
              <button type="button" onClick={() => onVisit(card.clientId)}>
                进他家
              </button>
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}
