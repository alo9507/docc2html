//
//  Options.swift
//  docc2html
//
//  Created by Helge Heß.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

import Foundation
import Macro
import Logging

func usage() {
  let tool = path.basename(CommandLine.arguments.first ?? "docc2html")
  print(
    """
    Usage: \(tool) [-f/--force] <docc archive folders...> <target folder>
    
    Example:
    
      \(tool) SlothCreator.doccarchive /tmp/SlothCreator/
    
    Options:
    
      -f/--force:   overwrite/merge target directories and files
      -s/--silent:  silent logging
      -v/--verbose: verbose logging
      --keep-hash:  keep hashes in resource names
    """
  )
}

struct Options {

  let force         : Bool
  let keepHash      : Bool
  let archivePathes : [ String ]
  let targetPath    : String
  let logFactory    : ( String ) -> LogHandler
  
  var targetURL     : URL { URL(fileURLWithPath: targetPath) }

  init?(argv: [ String ]) {
    force    = argv.contains("--force")   || argv.contains("-f")
    keepHash = argv.contains("--keep-hash")

    let silent  = argv.contains("--silent")  || argv.contains("-s")
    let verbose = argv.contains("--verbose") || argv.contains("-v")

    logFactory = { label in
      var handler = StreamLogHandler.standardOutput(label: label)
      if      verbose { handler.logLevel = .trace }
      else if silent  { handler.logLevel = .error }
      return handler
    }
    
    let pathes  = process.argv.dropFirst().filter { !$0.hasPrefix("-") }
    guard pathes.count > 1 else { return nil }
    archivePathes = Array(pathes.dropLast())
    targetPath    = pathes.last ?? ""
  }
}