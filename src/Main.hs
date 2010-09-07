-- Td-tool -- a tool for tournament management.
--
-- Author : Ivan N. Veselov
-- Created: 23-Aug-2010
--
-- Copyright (C) 2010 Ivan N. Veselov
--
-- License: BSD3
--
-- | Main module, the entry point.

module Main where

import Types
import qualified RoundRobin as RR

import System.Console.Shell
import System.Console.Shell.Backend.Haskeline
import System.Console.Shell.ShellMonad

import Text.ParserCombinators.Parsec

import Control.Monad.Trans( liftIO )

data ShellState = ShellState {
      stPlayers :: [Player]
    , stMaxPlayerId :: Int
    , stTable :: Table
    }

-- shell interaction
react :: String -> Sh ShellState ()
react s = shellPutErrLn ("Unknown command: " ++ s)

-- known commands
cmds = [ exitCommand "quit"
       , helpCommand "help"
       , cmd "add" addPlayerCmd "Adds a new player"
       , cmd "showplayers" showPlayersCmd "Shows currently registered players"
       , cmd "showpairings" showPairingsCmd "Shows calculated pairings"
       , cmd "rr" roundRobinCmd "Makes Round-Robin pairings"
       , cmd "load" loadCmd "Loads players from file"
       , cmd "result" setResultCmd "Set result of the game. Usage: set <gameId> <result> (0, 1/2, 1, etc.)"
       ]

addPlayerCmd :: String -> Sh ShellState ()
addPlayerCmd name = do
    modifyShellSt
      (\(ShellState ps maxId t) ->
        ShellState (Player (maxId + 1) name 1800 Available : ps) (maxId + 1) t)
    shellPutStrLn (name ++ " added")

showPlayersCmd :: Sh ShellState ()
showPlayersCmd = getShellSt >>= mapM_ (shellPutStrLn . show) . stPlayers

showPairingsCmd :: Sh ShellState ()
showPairingsCmd = do
  st <- getShellSt
  mapM_ shellPutStrLn . ppTable (stPlayers st) . stTable $ st

roundRobinCmd :: Sh ShellState ()
roundRobinCmd = do
    st <- getShellSt
    let pairings = RR.makePairingsForAllRounds . stPlayers $ st
    mapM_ shellPutStrLn (ppTable (stPlayers st) pairings)
    modifyShellSt (\st -> st { stTable = pairings })

loadCmd :: File -> Sh ShellState ()
loadCmd (File f) = do
    result <- liftIO $ parseFromFile players f
    case result of
        Left err -> shellPutStrLn (show err)
        Right ps -> putShellSt (ShellState ps 0 [])

setResultCmd :: Int -> String -> Sh ShellState ()
setResultCmd gid res = do
    st <- getShellSt
    let table = setGameResult gid (parseGameResult res) (stTable st)
    modifyShellSt (\st -> st { stTable = table })

players :: Parser [Player]
players = sepEndBy player space >>= return

player :: Parser Player
player = do
    id' <- number <?> "player ID"
    char '.'
    many space
    name <- many1 (letter <|> char ' ' <|> char '.') <?> "player name"
    char ','
    many space
    r <- number <?> "rating"
    return $ Player id' name r Available

number :: Parser Int
number = do
    digits <- many1 digit
    return (read digits)

shellDescr :: ShellDescription ShellState
shellDescr = (mkShellDescription cmds react) {
      commandStyle = OnlyCommands
    , greetingText = Just "Welcome to td-tool v0.1, mister tournament director!\n"
    }

main :: IO ()
main = do
    runShell shellDescr haskelineBackend (ShellState [] 0 [])
    return ()
