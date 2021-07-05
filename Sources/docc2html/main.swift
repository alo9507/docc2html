//
//  main.swift
//  docc2html
//
//  Created by Helge Heß.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

import Foundation
import Logging // @apple/swift-log

// MARK: - Parse Commandline Arguments & Usage

guard let options = Options(argv: CommandLine.arguments) else {
  usage()
  exit(ExitCode.notEnoughArguments.rawValue)
}

LoggingSystem.bootstrap(options.logFactory)

let exporter = DocCStaticExporter(
  target        : DocCFileSystemExportTarget(targetPath: options.targetPath),
  archivePathes : options.archivePathes,
  options       : options.exportOptions
)

do {
  try exporter.export()
}
catch let error as DocCStaticExportError {
  switch error {
    // add cases as they arrive
  }
}
catch let error as ExitCode {
  exit(error.rawValue)
}
catch {
  exporter.logger.error("Unexpected error:", error)
  exit(99)
}
