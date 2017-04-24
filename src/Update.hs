module Update where

import Types
import Draw
import Init
import Cannon

-- | Обновить состояние игровой вселенной.
updateUniverse :: Float -> Universe -> Universe
updateUniverse dt u
  | isGameOver dt u = u { universeGameOver = Just initGameOver }
  | fst (isWithPlatform dt u) = (upUniverse dt u) {universePlayer = keepPlayer dt (universePlayer u)}
  | snd (isWithPlatform dt u) = (upUniverse dt u) {universePlayer = holdPlayer dt (universePlayer u)}
  | otherwise = (upUniverse dt u) {universePlayer = updatePlayer dt (universePlayer u)}
 
-- | Обновление вселенной.
upUniverse:: Float -> Universe -> Universe 
upUniverse dt u = u { universePlatforms  = updatePlatforms  dt (universePlatforms  u)(universePlayer u)
      , universeScore  = (universeScore u) + dt
      , universeBackground = updateBackground dt (universeBackground u)
      , universeCannon = updateCannon dt u
      }

-- | Проверка на столкновение.
isWithPlatform :: Float -> Universe -> (Bool, Bool)
isWithPlatform dt u = playerWithPlatform
  where
    playerWithPlatform = (collision dt (universePlayer u) (universePlatforms u))

-- | Конец игры?
isGameOver :: Float -> Universe -> Bool
isGameOver dt u = playerBelowFloor || playerBelowRoof || (playerKilled dt u)
  where
    playerBelowRoof = playerHeight (universePlayer u) >  screenUp - 30
    playerBelowFloor = playerHeight (universePlayer u) < screenDown + 30

-- | 
playerKilled :: Float -> Universe -> Bool
playerKilled dt u = or (map (isKilled dt player) bullets)
  where 
    bullets = cannonBullets (universeCannon u)
    player = universePlayer u

-- |
isKilled :: Float -> Player -> Bullet -> Bool
isKilled dt player bullet = or[ (collidesHelper (playerSquare player dt) (bulletSquare bullet dt))
                              , (collidesHelper (rotateLeft (playerSquare player dt)) (rotateLeft (bulletSquare bullet dt)))
                              , (collidesHelper (rotateRight (playerSquare player dt)) (rotateRight (bulletSquare bullet dt)))
                              , (collidesHelper (bulletSquare bullet dt) (playerSquare player dt))]

-- |
bulletSquare :: Bullet -> Float -> Square
bulletSquare bullet dt = Square {
          xCoordinateLeft = (bulletWidth bullet) - bulletsWidth /2,
          yCoordinateRight = bulletHeight bullet - bulletsHeight/2, 
          xCoordinateRight = (bulletWidth bullet) + bulletsWidth /2,
          yCoordinateLeft = (bulletHeight bullet) + bulletsHeight/2, 
          xSpeed = 0,
          ySpeed = bulletSpeed * dt
}

-- | Сталкивается ли игрок с любыми из
-- бесконечного списка ворот?
collision :: Float -> Player -> [Platform] -> (Bool, Bool)
collision _ _ [] = (False, False)
collision dt player platforms = tupleOr (map (collides dt player) (takeWhile onScreen platforms))
  where
    onScreen (_, offset, _) = offset - platformHeight > screenDown

-- | Проверка на столкновение свреху.
tupleOrFirst :: [(Bool, Bool)] -> Bool
tupleOrFirst [] = False
tupleOrFirst list = or (map fst list)

-- | Проверка на столкновение сбоку.
tupleOrSecond :: [(Bool, Bool)] -> Bool
tupleOrSecond [] = False
tupleOrSecond list = or (map snd list)

-- | Свести список кортежей к одному кортежу.
tupleOr :: [(Bool, Bool)] -> (Bool, Bool)
tupleOr [] = (False, False)
tupleOr list = ((tupleOrFirst list), (tupleOrSecond list))

-- | Перевернуть прямоугольник, для проверки на столкновение слева.
rotateLeft :: Square -> Square
rotateLeft square = Square {
                  yCoordinateRight = -(xCoordinateRight square),
                  yCoordinateLeft = -(xCoordinateLeft square),
                  xCoordinateLeft = -(yCoordinateLeft square),
                  xCoordinateRight = -(yCoordinateRight square),
                  xSpeed = ySpeed square,
                  ySpeed = - (xSpeed square)
                }

-- | Перевернуть прямоугольник, для проверки на столкновение справа.
rotateRight :: Square -> Square
rotateRight square = Square {
                  yCoordinateRight = (xCoordinateLeft square),
                  yCoordinateLeft = (xCoordinateRight square),
                  xCoordinateLeft = (yCoordinateRight square),
                  xCoordinateRight = (yCoordinateLeft square),
                  xSpeed = ySpeed square,
                  ySpeed = xSpeed square
                }

-- |  Становится ли игрок на платформу?
collides :: Float -> Player -> Platform -> (Bool, Bool)
collides dt player (width, offset, life) = ((collidesHelper (playerSquare player dt) (platformSquare (width, offset, life) dt)), 
  or [(collidesHelper (rotateLeft (playerSquare player dt)) (rotateLeft (platformSquare (width, offset, life) dt))), 
  (collidesHelper (rotateRight (playerSquare player dt)) (rotateRight (platformSquare (width, offset, life) dt)))])

-- | Проверка на столкновение.
collidesHelper :: Square -> Square -> Bool
collidesHelper player platform = 
  (and [(yCoordinateRight player > yCoordinateRight platform),
  (yCoordinateRight player + ySpeed player < yCoordinateLeft platform + ySpeed platform), 
  (yCoordinateRight player + platformHeight/4 > yCoordinateLeft platform), 
  (xCoordinateLeft player < xCoordinateRight platform), 
  (xCoordinateRight player > xCoordinateLeft platform)])

-- | Обновление местоположения игрока по горизонтали.
keepPlayerOnScreen :: Float -> Player -> Player 
keepPlayerOnScreen dt player = player {
  playerWidth = (max (min w (playerWidth player) + dt * (playerSpeed player)) wm)
} 
  where
    w = 200
    wm = -200 

-- | Вспомогательная функция для игрока на платформе.
keepPlayerOnPlatform :: Float -> Player -> Player
keepPlayerOnPlatform dt player = player {
   playerFallingSpeed = speed,
   playerIsOnPlatform = True,
   playerHeight = playerHeight player + dt * speed
}

-- | Вспомогательная функция для игрока, столкнувшегося с платформой.
holdPlayerOnPlatform :: Float -> Player -> Player
holdPlayerOnPlatform dt player = player {
   playerSpeed = 0,
   playerIsOnPlatform = False,
   playerFallingSpeed = (playerFallingSpeed player) + dt * gravity,
   playerHeight = (playerHeight player) + dt * ((playerFallingSpeed player) + dt * (gravity / 2))
}

-- | Обновление игрока на платформе.
keepPlayer :: Float -> Player-> Player
keepPlayer dt player = keepPlayerOnScreen dt (keepPlayerOnPlatform dt player)

-- | Обновление игрока, столкнувшегося с платформой.
holdPlayer :: Float -> Player-> Player
holdPlayer dt player = keepPlayerOnScreen dt (holdPlayerOnPlatform dt player)

-- | Обновление скорости и расположения по вертикали игрока.
movePlayer :: Float -> Player -> Player
movePlayer dt player = player {
  playerFallingSpeed = (playerFallingSpeed player) + dt * gravity,
  playerIsOnPlatform = False,
  playerHeight = (playerHeight player) + dt * ((playerFallingSpeed player) + dt * (gravity / 2))
}

-- | Обновить платформы игровой вселенной.
updatePlatforms :: Float -> [Platform] -> Player -> [Platform]
updatePlatforms _ [] _ = []
updatePlatforms dt ((width, offset, time) : platforms) player
  | screenUp < offset = updatePlatforms dt platforms player
  | time - dt < 0 = updatePlatforms dt platforms player
  | collidesHelper (playerSquare player dt) (platformSquare (width, offset, time) dt) = (width, offset + dy, time - dt) : (updatePlatforms dt platforms player)
  | otherwise = (width, offset + dy, time) : (updatePlatforms dt platforms player)
  where
        dy  = dt * speed

-- | Пямоугольник игрока.
playerSquare :: Player -> Float -> Square
playerSquare player dt = Square {
          xCoordinateLeft = (playerWidth player - widthOfPlayer),
          yCoordinateRight = (playerHeight player - heigthOfPlayer), 
          xCoordinateRight = (playerWidth player + widthOfPlayer),
          yCoordinateLeft = (playerHeight player + heigthOfPlayer), 
          xSpeed = dt * (playerSpeed player),
          ySpeed = dt * (playerFallingSpeed player)
}

-- | Прямоугольник платформы.
platformSquare :: Platform -> Float -> Square
platformSquare (width, offset, time) dt = Square {
          xCoordinateLeft = width - platformWidth /2,
          yCoordinateRight = offset, 
          xCoordinateRight = width + platformWidth /2,
          yCoordinateLeft = offset + platformHeight, 
          xSpeed = 0,
          ySpeed = speed * dt
}
    
-- | Обновление состояния игрока.
updatePlayer :: Float -> Player -> Player
updatePlayer dt player = (keepPlayerOnScreen dt (movePlayer dt player))

updateBackground :: Float -> Background -> Background
updateBackground dt bg
  | (bgHeight1 bg) >= 7900 = bg {
  bgHeight1 = -bgHeight,
  bgHeight2 = (bgHeight2 bg) + dt * (bgSpeed bg)
}
  | (bgHeight2 bg) >= 7900 = bg {
  bgHeight1 = (bgHeight1 bg) + dt * (bgSpeed bg),
  bgHeight2 = -bgHeight
}
  | otherwise = bg {
  bgHeight1 = (bgHeight1 bg) + dt * (bgSpeed bg),
  bgHeight2 = (bgHeight2 bg) + dt * (bgSpeed bg)
}
