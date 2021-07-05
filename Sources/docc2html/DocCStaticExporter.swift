//
//  DocCStaticExporter.swift
//  docc2html
//
//  Created by Helge Heß.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

import Foundation
import Logging
import DocCArchive
import DocCHTMLExporter

open class DocCStaticExporter {
  
  public struct Options: OptionSet {
    public let rawValue : UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    static let force          = Options(rawValue: 1 << 0)
    static let keepHash       = Options(rawValue: 1 << 1)
    static let copySystemCSS  = Options(rawValue: 1 << 3)
    static let buildIndex     = Options(rawValue: 1 << 4)
    static let buildAPIDocs   = Options(rawValue: 1 << 5)
    static let buildTutorials = Options(rawValue: 1 << 6)
  }
  
  public let logger      : Logger
  public let options     : Options
  public let target      : DocCStaticExportTarget
  public let archiveURLs : [ URL ]
  public let stylesheet  = DZRenderingContext.defaultStyleSheet

  init(target: DocCStaticExportTarget, archivePathes: [ String ],
       options: Options, logger: Logger = Logger(label: "docc2html"))
  {
    self.target      = target
    self.archiveURLs = archivePathes.map(URL.init(fileURLWithPath:))
    self.options     = options
    self.logger      = logger
  }
  
  
  public func export() throws {
    if !target.doesTargetExist() {
      try target.ensureTargetDir("")
    }
    else if !options.contains(.force) {
      logger.error("Target directory exists (call w/ -f/--force to overwrite):",
                   target)
      throw ExitCode.targetDirectoryExists
    }
    else {
      logger.log("Existing output dir:", target)
    }
    
    let archives = try loadArchives(archiveURLs)
    try copyStaticResources(of: archives)
    try generatePages      (of: archives)
  }
  
  
  // MARK: - Loading Archives

  func loadArchives(_ pathes: [ URL ]) throws -> [ DocCArchive ] {
    var archives = [ DocCArchive ]()
    for url in pathes {
      do {
        archives.append(try DocCArchive(contentsOf: url))
      }
      catch {
        logger.error("Does not look like a .doccarchive:", error)
        throw ExitCode.expectedDocCArchive
      }
    }
    return archives
  }

  // MARK: - Copy Static Resources

  func copyStaticResources(of archives: [ DocCArchive ]) throws {
    for archive in archives {
      logger.log("Copy static resources of:", archive.url.lastPathComponent)

      if options.contains(.copySystemCSS) {
        let cssFiles = archive.stylesheetURLs()
        if !cssFiles.isEmpty {
          try target.copyCSS(archive.stylesheetURLs(),
                             keepHash: options.contains(.keepHash))
        }
      }
      
      try target.copyRaw(archive.userImageURLs(),    to: "images")
      try target.copyRaw(archive.userVideoURLs(),    to: "videos")
      try target.copyRaw(archive.userDownloadURLs(), to: "downloads")
      try target.copyRaw(archive.favIcons(),         to: "")
      
      try target.copyRaw(archive.systemImageURLs(),  to: "img",
                         keepHash: options.contains(.keepHash))
    }
    
    do {
      try target.ensureTargetDir("css")
      try target.write(stylesheet, to: "css/site.css")
    }
    catch {
      logger.error("Failed to write custom stylesheet:", error)
    }
  }

  // MARK: - Generate

  func generatePages(of archives: [ DocCArchive ]) throws {
    for archive in archives {
      logger.log("Generate archive:", archive.url.lastPathComponent)

      if options.contains(.buildAPIDocs),
         let folder = archive.documentationFolder()
      {
        try buildFolder(folder, into: "documentation",
                        buildIndex: options.contains(.buildIndex))
      }
      if options.contains(.buildTutorials),
         let folder = archive.tutorialsFolder()
      {
        try buildFolder(folder, into: "tutorials",
                        buildIndex: options.contains(.buildIndex))
      }
    }
  }
  
  
  // MARK: - Folders

  func buildFolder(_          folder : DocCArchive.DocumentFolder,
                   into relativePath : String,
                   buildIndex        : Bool) throws
  {
    try target.ensureTargetDir(relativePath)
    
    let subfolders = folder.subfolders()

    for subfolder in subfolders {
      let dest = relativePath + "/" + subfolder.url.lastPathComponent
      try buildFolder(subfolder, into: dest, buildIndex: buildIndex)
    }
    let subfolderNames = Set(subfolders.map { $0.url.lastPathComponent })

    for pageURL in folder.pageURLs() {
      do {
        let document   = try folder.document(at: pageURL)
        let baseName   = pageURL.deletingPathExtension().lastPathComponent
        let pathToRoot = String(repeating: "../", count: folder.level)
        
        var indexPath : String? {
          let isIndexPage = subfolderNames.contains(baseName)
          guard isIndexPage else { return nil }
          return relativePath + "/" + baseName + "/index.html"
        }
        
        do {
          let htmlPath = relativePath + "/" +
            pageURL
              .deletingPathExtension() // JSON
              .appendingPathExtension("html")
              .lastPathComponent

          logger.trace("Build:", document, "\n  to:", htmlPath)
          
          let ctx = DZRenderingContext(
            pathToRoot : pathToRoot,
            references : document.references,
            isIndex    : false,
            indexLinks : buildIndex
          )
          
          let html = try ctx.buildDocument(document, in: folder)
          
          try target.write(html, to: htmlPath)
        }
        
        if buildIndex, let htmlPath = indexPath {
          logger.trace("Index:", document, "\n  to:", htmlPath)
          
          let ctx = DZRenderingContext(
            pathToRoot : pathToRoot + "../",
            references : document.references,
            isIndex    : true,
            indexLinks : true
          )
          
          let html = try ctx.buildDocument(document, in: folder)
          
          try target.write(html, to: htmlPath)
        }
      }
      catch {
        logger.error("Could not process document at:", pageURL.path, error)
      }
    }
  }
}
