//
//  Poll.swift
//  ML_0
//
//  Created by Interactech on 21/06/2021.
//

import UIKit

public protocol Chromosome {
    func printDescription()
    var extra: Any? { get set }
}

public protocol DNA: Equatable & Hashable & Encodable & Decodable {
    static func empty() -> Self
    //    static func emptyChromosome() -> Chromosome
    init(copy: Self)
    func length() -> Int
    func calcFitness(val: Self?, best: CGFloat) -> (val: CGFloat, extraDimension: CGFloat)
    func mutate(rate: CGFloat) -> Self
    func find(target: Self, count: CGFloat) -> Bool
    func elementsEqual(_ other: Self) -> Bool
    static func ==(lhs: Self, rhs: Self) -> Bool
    static func random(length: Int, extra: Any?) -> Self
    static func +=(lhs: inout Self, rhs: Self)
    //    static func +=(lhs: inout Self, rhs: Chromosome)
    subscript(offset: Int) -> Self { get set }
    
    var isCompletedTask: ((_ val: Self) -> (Bool))? { get set }
    
    func distanceTo(target: Self) -> CGFloat
    
    func cleanBetweenGens()
    
    var extra: Any? { get set }
}

public protocol PollUpdates {
    func update(guess: String, string: String, lettersIndexs: [Int], done: Bool)
}

//fileprivate var randomFix: [T: Int]!
fileprivate let ratio: CGFloat =  0.1

public class MlPoll<T: DNA> {
    
    private let num: Int!
    private var length: Int!
    private var target: T!
    
    private var best: Agent<T>?
    
    public var finish: ((_ guess: Agent<T>, _ val: T, _ lettersIndexs: [Int], _ done: Bool) -> ())?
    
    public var generationChange: ((_ isShow: Bool, _ doneDrawing: @escaping () -> ()) -> ())?
    
    public var decisionHandler: ((_ index: Int, _ length: Int, _ fitnessVals: (queryVal: CGFloat, otherVal: CGFloat), _ extraDimension: CGFloat) -> (Bool)) = { index, length, fitnessVals, extraDimension  in
        return (index % 2 == 0)
    }
    
    public var fitnessHandler: ((_ val: T?) -> (CGFloat, CGFloat))?
    
    public var stopHandele: (() -> ())?
    
    private var gen: Int!
    
    private var rateOfChange: CGFloat = 1
    final private let rateOfChangeEvolution: CGFloat = 0.9996
    
    private let theSameMaxLoop = 4
    private var betterScoreMaxLoop = 6
    private var floatingPoint: CGFloat = 0
    
    private var lifeSpan: CGFloat = 0
    
    private var agents: [Agent<T>]!
    
    private var agentsGetters: [(_ index: Int) -> (Agent<T>?)]!
    
    public var delegate: PollUpdates?
    
    private var mutatingRate: CGFloat!
    
    private var moveSpeed: CGFloat!
    
    private var semaphore: DispatchSemaphore = DispatchSemaphore(value: 1)
    
    public init(num: Int = 100, lifeSpan: CGFloat = 0, moveSpeed: CGFloat = 0.5, mutatingRate: CGFloat = 0.1) {
        self.num = num
        self.lifeSpan = lifeSpan
        self.mutatingRate = mutatingRate
        self.moveSpeed = moveSpeed
        self.gen = 0
        self.length = 0
        self.agents = [Agent<T>]()
        self.agentsGetters = [(index: Int) -> (Agent<T>)]()
        self.agentCompleteTask = [Agent<T>]()
    }
    
    public func saveGeneration(key: String) -> Bool {
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory,
                                                            in: .userDomainMask).first {
            let pathWithFilename = documentDirectory.appendingPathComponent("bbhmlagents+\(key).json")
            do {
                let jsonEncoder = JSONEncoder()
                let jsonData = try jsonEncoder.encode(agents)
                let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)
                try jsonString?.write(to: pathWithFilename,
                                     atomically: true,
                                     encoding: .utf8)
                return true
            } catch {
                print("save fail: \(error.localizedDescription)")
                return false
            }
        }
        
        return false
    }
    
    public func loadGeneration(key: String) -> Bool {
        if let data = readLocalJSONFile(forName: "bbhmlagents+\(key)") {
            guard let agents = parse(jsonData: data) else {
                return false
            }
            self.agents = agents.map {
                let data = $0.getData()
                return createAgent(data: data, mutationRate: mutatingRate, extra: data?.extra)
            }
//            self.best = agents[Int.random(in: 0..<agents.count)]
            return true
        }
        
        return false
    }
    
    private func readLocalJSONFile(forName name: String) -> Data? {
        do {
            if let documentDirectory = FileManager.default.urls(for: .documentDirectory,
                                                                in: .userDomainMask).first {
                let fileURL = documentDirectory.appendingPathComponent("\(name).json")
                //                let fileUrl = URL(fileURLWithPath: filePath)
                let data = try Data(contentsOf: fileURL)
                return data
            }
        } catch {
            print("error: \(error)")
        }
        return nil
    }
    
    private func parse(jsonData: Data) -> [Agent<T>]? {
        do {
            let decodedData = try JSONDecoder().decode([Agent<T>].self, from: jsonData)
            return decodedData
        } catch {
            print("error: \(error)")
        }
        return nil
    }
    
    public func getAgentsGetters() -> [(_ index: Int) -> (Agent<T>?)] {
        return agentsGetters
    }
    
    public func stop() {
        //        semaphore.wait()
        stopHandele?()
        if timer != nil {
            timer.invalidate()
            timer = nil
        }
        stopRun = true
    }
    
    public func `continue`() {
        //        semaphore.signal()
        stopRun = false
        semaphore.signal()
        runGen()
    }
    
    public func getAgents() -> [Agent<T>] {
        //        let set = Set(agents)
        return agents
    }
    
    public func getGeneration() -> Int {
        //        let set = Set(agents)
        return gen
    }
    
    public func getBest() -> Agent<T>? {
        //        let set = Set(agents)
        return best
    }
    
    public func sortAgents() {
        agents.sort { (agent1, agent2) -> Bool in
            return agent1.fitnessVal! > agent2.fitnessVal!
        }
    }
    
    public func getUpdatedData() -> (guess: T, val: T, lettersIndexs: [Int], done: Bool) {
        guard let best = best else {
            return (String(repeating: empty, count: length) as! T, "Generation: \(0)\n\nGuss: {%@}\n\nSolved: \(0)%\n\nLetters so far:\n\n" as! T, [], false)
        }
        
        var letters = ""
        var indexs = [Int]()
        for i in 0..<(best.getData()?.length() ?? 0) {
            letters += best.getData()![i] == target[i] ? "\(best.getData()![i])" : empty
            if best.getData()![i] == target[i] {
                indexs.append(i)
            }
        }
        return (best.getData()!, "Generation: \(gen!)\n\nGuss: {%@}\n\nSolved: \(CGFloat(target.length()) / CGFloat(length) * 100)%\n\nLetters so far: \(letters)\n\n" as! T, indexs, false)
    }
    
    private var agentCompleteTask: [Agent<T>]!
    private var agentWithBestPointForGeneration: ((agent: Agent<T>, dist: CGFloat ,index: Int))? = nil
    
    public func start(target: T, lengthLimit: Int = 0, extra: Any...) {
        self.target = T(copy: target)
        self.length = Int(lifeSpan == 0 ? CGFloat((lengthLimit == 0 ? target.length() : lengthLimit)) : 20 * (lifeSpan / moveSpeed) + 1)
        self.gen = 0
        best = nil
        
        if agents.isEmpty {
            for _ in 0..<num {
                let agent = createAgent(mutationRate: mutatingRate, extra: extra)
                agents.append(agent)
                agentsGetters.append { [weak self] (index: Int) -> (Agent<T>?) in
                    guard let strongSelf = self else { return nil }
                    
                    if strongSelf.agents[index].getData() == target {
                        strongSelf.agentCompleteTask.append(strongSelf.agents[index])
                        return nil
                    }
                    
                    return strongSelf.agents[index]
                }
            }
        }
        
        self.runGen()
    }
    
    public func checkIfShouldKeep(agent: Agent<T>) {
        let dist = agent.getData()!.distanceTo(target: target)
        if agentWithBestPointForGeneration == nil || agentWithBestPointForGeneration!.dist < dist {
            agentWithBestPointForGeneration = (agent: agent, dist: dist, index: Int(agent.extraDimension ?? -1))
        }
    }
    
    public func resetAgents() {
        agents = [Agent<T>]()
        agentsGetters = [(Int) -> (Agent<T>)]()
    }
    
    private let empty =  "  _  "
    //    private var increaseLimit: CGFloat = 0.002
    
    private var safe = 0
    
    private var stopRun = false
    
    private var timer: Timer!
    
    private func runGen() {
        //        randomFix = [String: Int]()
        DispatchQueue.init(label: "Work").async { [self] in
            //        if safe < num / 2 {
            if lifeSpan == 0 {
                //                DispatchQueue.init(label: "Work").async {
                semaphore.wait()
                agentCompleteTask = [Agent<T>]()
                guard !isSolved() else {
                    return
                }
                selection()
                self.continue()
                semaphore.signal()
                //                }
                return
            }
            
            DispatchQueue.main.async {
                semaphore.wait()
                timer = Timer(timeInterval: TimeInterval(lifeSpan), repeats: false) { _ in
                    guard !stopRun else {
                        if timer != nil {
                            self.timer.invalidate()
                        }
                        self.timer = nil
                        return
                        
                    }
                    stop()
                    markBest()
                    selection()
                    cleanIfNeeded()
                    self.continue()
                    semaphore.signal()
                }
                
                RunLoop.current.add(timer, forMode: .common)
            }
        }
    }
    
    public func cleanIfNeeded() {
        for agent in agents {
            agent.cleanIfNeeded()
        }
    }
    
    private func selection() {
        self.evolution()
        self.generationChange?(true, {
           
        })
    }
    
    private func markBest () {
        var score: CGFloat = 0
        for agent in agents {
            if agent.fitnessVal! >= score {
                rateOfChange *= best != nil && best!.getData() == agent.getData() ? rateOfChangeEvolution : 1
                self.best = agent
                score = agent.fitnessVal!
            }
        }
    }
    
    private func isSolved() -> Bool {
        guard !didFinish() else {
            let guess = best!.getData()!
            
            var chromosomeIndexs = [Int]()
            for i in 0..<guess.length() {
                chromosomeIndexs.append(i)
            }
            
            finish?(best!, "Generation: \(gen!)\n\nGuss: {%@}\n\nSolved: \(100)%\n\nLetters so far: \(guess)\n\n" as! T, chromosomeIndexs, true)
            return true
        }
        
        return false
    }
    
    private func didFinish() -> Bool {
        var score: CGFloat = 0
        var best: Agent<T>!
        
        for agent in agents {
            guard !agent.find(target: target) else {
                self.best = agent
                return true
            }
            
            if agent.fitnessVal! >= score {
                rateOfChange *= best != nil && best.getData() == agent.getData() ? rateOfChangeEvolution : 1
                best = agent
                self.best = best
                score = agent.fitnessVal!
            }
        }
        
        return false
    }
    
    private func evolution() {
        safe -= 1
        newGeneration()
        safe += 1
    }
    
    private final let fixedGrowth: CGFloat = 0.1
    private lazy var normalizeDimension: CGFloat = 1.44 * (moveSpeed > 0 ? ((lifeSpan / moveSpeed) + 1) : lifeSpan)
//    private var bestPointOverAll: ((agent: Agent<T>, index: Int))? = nil
    
    private func newGeneration() {
        
        for i in 0..<agents.count {
            if agentCompleteTask.contains(where: { (agent) -> Bool in return agents[i] == agent }) {
                let extraDimension = agents[i].extraDimension
                let growth = extraDimension != nil ? pow((1 - (extraDimension! / normalizeDimension)), 2): fixedGrowth
                let newFitnessVal = min(1, (agents[i].fitnessVal! + growth))
                //                print("Before Best Vs Win: Best: \(best!.fitnessVal!), Win: \(agents[i].fitnessVal!), extra: \(growth)")
                agents[i].fitnessVal! = newFitnessVal
                
                agents[i].immutable = extraDimension != nil ? Int(extraDimension!) : nil
            }
            else if !agentCompleteTask.isEmpty {
                agents[i].immutable = nil
            }
            else if let best = agentWithBestPointForGeneration?.agent, agents[i] == best {
                agents[i].immutable = agentWithBestPointForGeneration?.index
            }
        }
        
        agentCompleteTask = [Agent<T>]()
        agentWithBestPointForGeneration = nil
        
        let sort = agents!
        let sorted = sort.sorted { (obj, obj2) -> Bool in
            guard let fitness = obj.fitnessVal , let fitness2 = obj2.fitnessVal else { return false }
            return fitness > fitness2
        }
        
        agents = sorted
        var i = agents.count / 4
        while i > 0 {
            let r = Int.random(in: 0..<agents.count)
            i -= 1
            //            print("increase limit: \(increaseLimit) , val: \(agents[r].fitnessVal! * 2)")
            let bestScore = (best?.fitnessVal != nil && best!.fitnessVal! > 0) ? best!.fitnessVal! : 0.01
            if agents[r].fitnessVal! < bestScore * 0.4 {
                let _ = agents.remove(at: r)
                //                print("removed: \(removed.toString())")
            }
        }
    
        //        increaseLimit *= 1.002
        //        print("increaseLimit: \(increaseLimit)")
        //        increaseLimit = min(0.04, increaseLimit)
        
        var tempAgents = [Agent<T>]()
        
        for _ in 0..<num {
            var a = pickOne()
            var b = pickOne()
            
            var same = a.getData() == b.getData()
            rateOfChange *= same ? rateOfChangeEvolution : 1

            //            var c = 0
            var stopCount = 0
            while same && stopCount < theSameMaxLoop {
                //                c += 1
                let fix = tryToFix(a: a, b: b)
                a = fix.a
                b = fix.b
                stopCount += 1
                same = a.getData() == b.getData()
                //                print("loop: \(c)")
            }
            
            //            print("total for loop: \(c)")
            
            var agent = combine(a: a, b: b).mutation()
            
            stopCount = 0
            
            while agent.fitnessVal! < a.fitnessVal! && agent.fitnessVal! < b.fitnessVal! && stopCount < betterScoreMaxLoop {
                //                c += 1
//                print("betterScoreMaxLoop: \(betterScoreMaxLoop)")
                let fix = tryToFix(a: a, b: b)
                a = fix.a
                b = fix.b
                agent = combine(a: a, b: b).mutation()
                stopCount += 1
                floatingPoint += stopCount == betterScoreMaxLoop ? lifeSpan == 0 ? 0.004 : 0.8 : 0
                if floatingPoint >= 1 {
                    betterScoreMaxLoop -= 1
                    betterScoreMaxLoop = max(betterScoreMaxLoop, 0)
                    floatingPoint -= 1
                }
            }
//
            //            print("total for loop: \(c)")
            
            if rateOfChange < 0.0005 {
                //                print("rate of change was: \(rateOfChange)")
                rateOfChange = 0.5
                agent = agent.mutation()
            }
            
            tempAgents.append(agent)
        }
        
        agents = tempAgents
        
        gen += 1
    }
    
    private func tryToFix(a: Agent<T>, b: Agent<T>) -> (a: Agent<T>, b: Agent<T>) {
        var a = a
        var b = b
        let r = CGFloat.random(in: 0...1)
        if r > 0.5 {
            a = a.mutation()
        }
        else {
            b = b.mutation()
        }
        
        return (a: a, b: b)
    }
    
    private func combine(a: Agent<T>, b: Agent<T>) -> Agent<T> {
    var dna = T.empty()
        var maxAgent: Agent<T>!
        var minLength = 0
        
        if a.getData()?.length() ?? 0 < b.getData()?.length() ?? 0 {
            minLength = a.getData()?.length() ?? 0
            maxAgent = b
        }
        else {
            minLength = b.getData()?.length() ?? 0
            maxAgent = a
        }
        
        for i in 0..<minLength {
            if let aim = a.immutable, i <= aim {
                dna += a.getDnaAt(index: i) ?? T.empty()
            }
            else if let bim = b.immutable, i <= bim {
                dna += b.getDnaAt(index: i) ?? T.empty()
            }
            else if decisionHandler(i, minLength, (a.fitnessVal!, b.fitnessVal!), a.extraDimension!) {
                dna += a.getDnaAt(index: i) ?? T.empty()
            }
            else {
                dna += b.getDnaAt(index: i) ?? T.empty()
            }
        }
        
        for j in 0..<(length - minLength) {
            dna += maxAgent.getDnaAt(index: (minLength + j)) ?? T.empty()
        }
        
        return createAgent(data: T(copy: dna), mutationRate: mutatingRate)
    }
    
    private func createAgent(data: T? = nil, mutationRate: CGFloat, extra: Any? = nil) -> Agent<T> {
        
        let agent = Agent(mutationRate: mutationRate,
                          random: { [self] () -> (T) in
                            let agentData = data ?? T.random(length: length, extra: extra)
                            return agentData
                          }, fitness: { [self] val in
                            let bestScore = (best?.fitnessVal != nil && best!.fitnessVal! > 0) ? best!.fitnessVal! : 0.01
                            return fitnessHandler?(val!) ?? val!.calcFitness(val: target, best: bestScore)
                          }, getDNA: { val, index in
                            return val![index]
                          }, mutate: { val, rate  in
                            return val!.mutate(rate: rate)
                          })
        
        agent.askToBeKept = { [weak self] agent in
            guard let strongSelf = self else { return }
            strongSelf.checkIfShouldKeep(agent: agent)
        }
        
        return agent
    }
    
    private func pickOne() -> Agent<T> {
        var index = 0
        let end: CGFloat = lifeSpan == 0 ? 1 : (best?.fitnessVal ?? 0.4)
        var r = CGFloat.random(in: 0...end)
        
        while r > 0 {
            r = r - (agents![index].fitnessVal ?? 0)
            index += 1
            index %= agents!.count
        }
        index -= 1
        if index < 0 {
            index = agents!.count + index
        }
        return agents![index]
    }
    
    
    private func getValueAt(val: T?, index: Int) -> T {
        guard let val = val, index < val.length() else { return T.empty() }
        return val[index]
    }
}

public class Agent<T: DNA>: Encodable & Decodable {
    private var random: (() -> (T))?
    private var fitness: ((T?) -> (val: CGFloat, count: CGFloat))?
    private var getDNA: ((T?, _ index: Int) -> (T))?
    private var mutate: ((T?, _ rate: CGFloat) -> (T))?
    private lazy var data: T? = random?()
    
    private lazy var calc = fitness?(data)
    public lazy var fitnessVal = calc?.val
    lazy var extraDimension = calc?.count
    
    fileprivate var immutable: Int? = nil
    
    fileprivate var askToBeKept: ((_ agent: Agent<T>) -> ())!
    
    private var mutationRate: CGFloat!
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode(T.self, forKey: .data)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
    }
    
    public func hash(into hasher: inout Hasher) {
        data.hash(into: &hasher)
    }
    
    private init() {
        data = T.empty()
        fitnessVal = 0
        extraDimension = 0
    }
    
    init(mutationRate: CGFloat = 0.1, random: @escaping () -> (T), fitness: @escaping (T?) -> (CGFloat, CGFloat), getDNA: @escaping (T?, _ index: Int) -> (T), mutate: @escaping (T?, CGFloat) -> (T)) {
        self.mutationRate = mutationRate
        self.random = random
        self.fitness = fitness
        self.mutate = mutate
        self.getDNA = getDNA
    }
    
    init(agent: Agent) {
        self.mutationRate = agent.mutationRate
        self.random = agent.random
        self.fitness = agent.fitness
        self.mutate = agent.mutate
        self.getDNA = agent.getDNA
        self.data = T(copy: agent.data!)
    }
    
    enum CodingKeys: String, CodingKey {
        case data
    }
    
    public static func empty() -> Agent<T> {
        return Agent<T>()
    }
    
    public func toString() -> String {
        return "Data = \(data ?? "No Data" as! T), Fitness = \(fitnessVal ?? 0)"
    }
    
    func getDnaAt(index: Int) -> T? {
        return getDNA?(data, index)
    }
    
    public static func == (lhs: Agent<T>, rhs: Agent<T>) -> Bool {
        return lhs.data == rhs.data
    }
    
    @discardableResult
    func mutation() -> Agent<T> {
        data = mutate?(data, mutationRate)
        return self
    }
    
    private let sem = DispatchSemaphore(value: 1)
    
    public func getData() -> T? {
        sem.wait()
        defer {
            sem.signal()
        }
        return data
    }
    
    public func checkIfShouldKeep()  {
        askToBeKept(self)
    }
    
    func find(target: T) -> Bool {
        return data?.find(target: target, count: extraDimension ?? 0) ?? false
    }
    
    func cleanIfNeeded() {
        data?.cleanBetweenGens()
    }
}
