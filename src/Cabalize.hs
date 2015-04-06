{-# LANGUAGE QuasiQuotes, RecordWildCards #-}
module Cabalize (
  cabalize
-- exported for testing
, renderPackage
) where

import           Prelude ()
import           Prelude.Compat

import           Data.List (sort, intercalate)
import           Data.String.Interpolate
import           System.Exit.Compat

import           Util
import           Config

renderExecutables :: [Executable] -> String
renderExecutables = intercalate "\n" . map renderExecutable

renderExecutable :: Executable -> String
renderExecutable executable@Executable{..} = stripEmptyLines [i|
executable #{executableName}
|] ++ renderExecutableSection executable

renderTests :: [Executable] -> String
renderTests = intercalate "\n" . map renderTest

renderTest :: Executable -> String
renderTest executable@Executable{..} = stripEmptyLines [i|
test-suite #{executableName}
  type: exitcode-stdio-1.0
|] ++ renderExecutableSection executable


renderExecutableSection :: Executable -> String
renderExecutableSection Executable{..} = stripEmptyLines [i|
#{if null executableSourceDirs then "" else "  hs-source-dirs: " ++ intercalate ", " executableSourceDirs}
  main-is: #{executableMain}
  build-depends:
      #{intercalate "\n    , " $ sort executableDependencies}
  ghc-options: #{unwords executableGhcOptions}
  default-language: Haskell2010
|]

configFile :: FilePath
configFile = "package.yaml"

cabalize :: IO (FilePath, String)
cabalize = do
  mPackage <- readConfig configFile
  case mPackage of
    Just package -> do
      let output = concat [
              "-- This file has been generated from " ++ configFile ++ " by Cabalize.\n"
            , renderPackage package
            ]
      return (packageName package ++ ".cabal", output)
    Nothing -> die [i|could not parse #{configFile}|]

renderPackage :: Package -> String
renderPackage Package{..} = unlines fields ++ renderExecutables packageExecutables ++ renderTests packageTests
  where
    formatField :: String -> String -> String
    formatField name value = name ++ ": " ++ value

    addField :: String -> String -> [String] -> [String]
    addField name value = (formatField name value :)

    mayField :: String -> Maybe String -> [String] -> [String]
    mayField name = addWith (formatField name)

    addWith :: (a -> String) -> Maybe a -> [String] -> [String]
    addWith f value = maybe id ((:) . f) value

    fields =
      addField "name" packageName $
      addField "version" packageVersion $
      mayField "synopsis" packageSynopsis $
      mayField "description" packageDescription $
      mayField "category" packageCategory $
      mayField "author" packageAuthor $
      mayField "maintainer" packageMaintainer $
      mayField "copyright" packageCopyright $
      mayField "license" packageLicense $
      mayField "license-file" packageLicenseFile $
      addField "build-type" "Simple" $
      addField "cabal-version" ">= 1.10" $
      addWith renderLibrary packageLibrary
      []

renderLibrary :: Library -> String
renderLibrary Library{..} = [i|
library
  hs-source-dirs: src
  exposed-modules:
#{intercalate "\n" . map ("      " ++) $ libraryExposedModules}
  other-modules:
#{intercalate "\n" . map ("      " ++) $ libraryOtherModules}
  build-depends:
      #{intercalate "\n    , " $ sort libraryDependencies}
  default-language: Haskell2010
|]
