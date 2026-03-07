//
//  MIDIInstrumentViewController.swift
//  MusicFun
//
//  Created by Robert Arvin Lee on 7/3/26.
//

import SwiftUI
import AVFoundation

// MARK: - 1. MIDI Instrument Data
enum GeneralMIDIInstrument: Int, CaseIterable, Identifiable {
    case acousticGrandPiano = 0, brightAcousticPiano, electricGrandPiano, honkyTonkPiano, electricPiano1, electricPiano2, harpsichord, clavi
    case celesta = 8, glockenspiel, musicBox, vibraphone, marimba, xylophone, tubularBells, dulcimer
    case drawbarOrgan = 16, percussionOrgan, rockOrgan, churchOrgan, reedOrgan, accordion, harmonica, tangoAccordion
    case acousticGuitarNylon = 24, acousticGuitarSteel, electricGuitarJazz, electricGuitarClean, electricGuitarMuted, overdrivenGuitar, distortionGuitar, guitarHarmonics
    case acousticBass = 32, electricBassFinger, electricBassPick, fretlessBass, slapBass1, slapBass2, synthBass1, synthBass2
    case violin = 40, viola, cello, contrabass, tremoloStrings, pizzicatoStrings, orchestralHarp, timpani
    case stringEnsemble1 = 48, stringEnsemble2, synthStrings1, synthStrings2, choirAahs, voiceOohs, synthVoice, orchestraHit
    case trumpet = 56, trombone, tuba, mutedTrumpet, frenchHorn, brassSection, synthBrass1, synthBrass2
    case sopranoSax = 64, altoSax, tenorSax, baritoneSax, oboe, englishHorn, bassoon, clarinet
    case piccolo = 72, flute, recorder, panFlute, blownBottle, shakuhachi, whistle, ocarina
    case lead1Square = 80, lead2Sawtooth, lead3Calliope, lead4Chiff, lead5Charang, lead6Voice, lead7Fifths, lead8BassAndLead
    case pad1NewAge = 88, pad2Warm, pad3Polysynth, pad4Choir, pad5Bowed, pad6Metallic, pad7Halo, pad8Sweep
    case fx1Rain = 96, fx2Soundtrack, fx3Crystal, fx4Atmosphere, fx5Brightness, fx6Goblins, fx7Echoes, fx8SciFi
    case sitar = 104, banjo, shamisen, koto, kalimba, bagpipe, fiddle, shanai
    case tinkleBell = 112, agogo, steelDrums, woodblock, taikoDrum, melodicTom, synthDrum, reverseCymbal
    case guitarFretNoise = 120, breathNoise, seashore, birdTweet, telephoneRing, helicopter, applause, gunshot

    var id: Int { self.rawValue }
    
    var name: String {
        "\(self)".replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression).capitalized
    }
    
    var family: String {
        let families = ["Piano", "Percussion", "Organ", "Guitar", "Bass", "Strings", "Ensemble", "Brass", "Reed", "Pipe", "Synth Lead", "Synth Pad", "Synth FX", "Ethnic", "Percussive", "SFX"]
        return families[self.rawValue / 8]
    }
}

// MARK: - 3. SwiftUI Interface
class MIDIInstrumentViewController: UIViewController {

    // MARK: - Properties
//    private let midiEngine = MIDIEngine()  Using the engine from previous step
    private var tableView: UITableView!
    private var dataSource: UITableViewDiffableDataSource<String, GeneralMIDIInstrument>!
    private var searchController = UISearchController(searchResultsController: nil)
    
    private var selectedInstrument: GeneralMIDIInstrument = .acousticGrandPiano

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureDataSource()
        applySnapshot(animating: false)
    }

    // MARK: - UI Setup
    private func setupUI() {
        title = "GeneralUser GS"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .systemBackground

        // TableView Setup
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "InstrumentCell")
        view.addSubview(tableView)

        // Search Setup
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Instruments"
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }

    // MARK: - Data Source Logic
    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<String, GeneralMIDIInstrument>(tableView: tableView) { (tableView, indexPath, instrument) -> UITableViewCell? in
            let cell = tableView.dequeueReusableCell(withIdentifier: "InstrumentCell", for: indexPath)
            
            var content = cell.defaultContentConfiguration()
            content.text = instrument.name
            content.secondaryText = "Program: \(instrument.rawValue)"
            cell.contentConfiguration = content
            
            // Show checkmark if selected
            cell.accessoryType = (instrument == self.selectedInstrument) ? .checkmark : .none
            
            return cell
        }
    }

    private func applySnapshot(animating: Bool = true, filter: String? = nil) {
        var snapshot = NSDiffableDataSourceSnapshot<String, GeneralMIDIInstrument>()
        
        // Filter logic
        let allInstruments = GeneralMIDIInstrument.allCases
        let filtered = allInstruments.filter { inst in
            guard let filter = filter, !filter.isEmpty else { return true }
            return inst.name.localizedCaseInsensitiveContains(filter)
        }

        // Group into families for sections
        let families = Array(Set(filtered.map { $0.family })).sorted()
        
        for family in families {
            snapshot.appendSections([family])
            let familyMembers = filtered.filter { $0.family == family }
            snapshot.appendItems(familyMembers, toSection: family)
        }

        dataSource.apply(snapshot, animatingDifferences: animating)
    }
}

// MARK: - TableView Delegate
extension MIDIInstrumentViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let instrument = dataSource.itemIdentifier(for: indexPath) else { return }
        
        // Update selection logic
        selectedInstrument = instrument
        
        AdvancedMIDIPlayer.shared.setInstrument(instrument)
            
        // Refresh the visible cells to update the checkmark
        var snapshot = dataSource.snapshot()
        snapshot.reloadSections(snapshot.sectionIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - Search Results Updating
extension MIDIInstrumentViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        applySnapshot(filter: searchController.searchBar.text)
    }
}
