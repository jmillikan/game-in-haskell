import Testing.Sound
import Testing.Backend
import Testing.Graphics
import Testing.Game

import System.Exit ( exitSuccess )
import System.Random
import Control.Concurrent (threadDelay)
import Control.Monad (unless, join)
import Control.Monad.Fix (fix)
import FRP.Elerea.Simple as Elerea
import Testing.GameTypes
import Options
import Control.Applicative ((<*>), pure)
import Data.Aeson
import Data.Maybe (fromMaybe)
import qualified Data.ByteString.Lazy as B (readFile)

width :: Int
width = 640

height :: Int
height = 480

data MainOptions = MainOptions {
  optTesting :: Bool
, optStartFile :: String
}

instance Options MainOptions where
  defineOptions = pure MainOptions
                <*> simpleOption "testing" False
                      "testing configuration"
                <*> simpleOption "start-state" ""
                      "file containing start state"

getStartState :: MainOptions -> IO StartState
getStartState opts = if optTesting opts
                       then fmap (\mb -> fromMaybe defaultStart mb) $ fmap decode $ B.readFile (optStartFile opts)
                       else return defaultStart
main :: IO ()
main = runCommand $ \opts _ -> do
    startState <- getStartState opts
    (snapshot, snapshotSink) <- external False
    (directionKey, directionKeySink) <- external (False, False, False, False)
    (shootKey, shootKeySink) <- external (False, False, False, False)
    (windowSize,windowSizeSink) <- external (fromIntegral width, fromIntegral height)
    randomGenerator <- newStdGen
    glossState <- initState
    textures <- loadTextures
    withWindow width height windowSizeSink "Game-Demo" $ \win -> do
      withSound $ \_ _ -> do
          sounds <- loadSounds
          backgroundMusic (backgroundTune sounds)
          network <- start $ hunted win windowSize directionKey shootKey randomGenerator textures glossState sounds startState snapshot
          fix $ \loop -> do
               readInput win directionKeySink shootKeySink snapshotSink
               join network
               threadDelay 20000
               esc <- exitKeyPressed win
               unless esc loop
          exitSuccess
