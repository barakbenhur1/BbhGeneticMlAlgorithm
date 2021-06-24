//
//  Poll.swift
//  ML_0
//
//  Created by Interactech on 21/06/2021.
//

import UIKit

public protocol DNA: Equatable & Sequence & Hashable {
    static func empty() -> Self
    init()
    func length() -> Int
    func calcFitness(val: Self?, best: CGFloat) -> (val: CGFloat, count: CGFloat)
    func mutate(rate: CGFloat) -> Self
    func find(target: Self, count: CGFloat) -> Bool
    func elementsEqual(_ other: Self) -> Bool
    static func ==(lhs: Self, rhs: Self) -> Bool
    static func random(length: Int) -> Self
    static func += (lhs: inout Self, rhs: Self)
    subscript(offset: Int) -> Self { get set }
}

public protocol PollUpdates {
//    associatedtype T = String
    func update(guess: String, string: String, lettersIndexs: [Int], done: Bool)
}

//fileprivate var randomFix: [T: Int]!
fileprivate let ratio: CGFloat =  0.1

public class MlPoll<T: DNA> {
    
    private let num: Int!
    private var length: Int!
    private var target: T!
    
    private var best: Agent<T>?
    
    public var finish: ((_ guess: T, _ val: T, _ lettersIndexs: [Int], _ done: Bool) -> ())?
    
    private var gen: Int!
    
    private var rateOfChange: CGFloat = 1
    final private let rateOfChangeEvolution: CGFloat = 0.9996
    
    private let theSameMaxLoop = 4
    private var betterScoreMaxLoop = 6
    private var floatingPoint: CGFloat = 0
    
    private var lifeSpan: CGFloat = 0
    
    private var agents: [Agent<T>]!
    
    public var delegate: PollUpdates?
    
    public init(num: Int, lifeSpan: CGFloat = 0) {
        self.num = num
        self.lifeSpan = lifeSpan
        self.gen = 0
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
        for i in 0..<length {
            letters += best.getData()![i] == target[i] ? "\(best.getData()![i])" : empty
            if best.getData()![i] == target[i] {
                indexs.append(i)
            }
        }
        return (best.getData()!, "Generation: \(gen!)\n\nGuss: {%@}\n\nSolved: \(CGFloat(best.count!) / CGFloat(length) * 100)%\n\nLetters so far: \(letters)\n\n" as! T, indexs, false)
    }
    
    public func start(target: T) {
        self.target = target
        self.length = target.length()
        self.gen = 0
        best = nil
        agents = [Agent<T>]()
        
        DispatchQueue.init(label: "Work").async { [self] in
            for _ in 0..<num {
                agents.append(createAgent())
            }
            
            self.runGen()
        }
    }
    
    private let empty =  "  _  "
//    private var increaseLimit: CGFloat = 0.002
    
    private var safe = 0
    
    private func runGen() {
        
//        randomFix = [String: Int]()
        
        guard !didFinish() else {
            let guess = best!.getData()!
           
            var chromosomeIndexs = [Int]()
            for i in 0..<guess.length() {
                chromosomeIndexs.append(i)
            }
            
            finish?(guess, "Generation: \(gen!)\n\nGuss: {%@}\n\nSolved: \(100)%\n\nLetters so far: \(guess)\n\n" as! T, chromosomeIndexs, true)
            
            return
        }
        
        evolution()
        
        DispatchQueue.init(label: "Work").asyncAfter(deadline: .now() + Double(lifeSpan), execute: {
            //        if safe < num / 2 {
            self.runGen()
            //        }
        })
    }
    
    private func didFinish() -> Bool {
        var score: CGFloat = 0
        var best: Agent<T>!
        
        //        print("Rate Of Change: \(rateOfChange)")
        for i in 0..<agents.count {
            //            print(agent.toString())
            
            guard !agents[i].find(target: target) else {
//                print("finish: \(agents[i].toString())")
                self.best = agents[i]
                return true
            }
            
            if agents[i].fitnessVal! >= score {
                rateOfChange *= best != nil && best.getData() == agents[i].getData() ? rateOfChangeEvolution : 1
                best = agents[i]
                self.best = best
                score = agents[i].fitnessVal!
            }
        }
        
        return false
        
    }
    
    private func evolution() {
        safe -= 1
        
        newGeneration()
        
        safe += 1
    }
    
    private func newGeneration() {
        var tempAgents = [Agent<T>]()
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
            if agents[r].fitnessVal! < best!.fitnessVal! * 0.4 {
                let _ = agents.remove(at: r)
//                print("removed: \(removed.toString())")
            }
        }
//        agents.popLast()
//        agents.popLast()
//        increaseLimit *= 1.002
//        print("increaseLimit: \(increaseLimit)")
//        increaseLimit = min(0.04, increaseLimit)
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
                print("betterScoreMaxLoop: \(betterScoreMaxLoop)")
                let fix = tryToFix(a: a, b: b)
                a = fix.a
                b = fix.b
                agent = combine(a: a, b: b).mutation()
                stopCount += 1
                floatingPoint += stopCount == betterScoreMaxLoop ? 0.004 : 0
                if floatingPoint >= 1 {
                    betterScoreMaxLoop -= 1
                    betterScoreMaxLoop = max(betterScoreMaxLoop, 0)
                    floatingPoint -= 1
                }
            }
            
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
        var string = T.empty()
        for i in 0..<length {
            if i > length / 2 {
                string += a.getDnaAt(index: i) ?? T.empty()
            }
            else {
                string += b.getDnaAt(index: i) ?? T.empty()
            }
        }
        
        return createAgent(data: string)
    }
    
    private func createAgent(data: T? = nil) -> Agent<T> {
        Agent(random: { [self] in
            return data ?? T.random(length: length)
        }, fitness: { [self] val in
            return target.calcFitness(val: val, best: best?.fitnessVal ?? 0.01)
        }, getDNA: { [self] val, index in
            return getValueAt(val: val, index: index)
        }, mutate: { [self] val, rate  in
            return val!.mutate(rate: rate)
        })
    }
    
    private func pickOne() -> Agent<T> {
        var index = 0
        var r = CGFloat.random(in: 0...1)
    
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
        guard let val = val else { return T.empty() }
        return val[index]
    }
}

public class Agent<T: DNA>  {
    private var random: (() -> (T))?
    private var fitness: ((T?) -> (val: CGFloat, count: CGFloat))?
    private var getDNA: ((T?, _ index: Int) -> (T))?
    private var mutate: ((T?, _ rate: CGFloat) -> (T))?
    private lazy var data: T? = random?()

    private lazy var calc = fitness?(data)
    public lazy var fitnessVal = calc?.val
    lazy var count = calc?.count
    
    private var mutationRate: CGFloat!
    
    public func hash(into hasher: inout Hasher) {
      data.hash(into: &hasher)
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
    }
    
    func toString() -> String {
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
    
    public func getData() -> T? {
        return data
    }
    
    func find(target: T) -> Bool {
        return data?.find(target: target, count: count ?? 0) ?? false
    }
}

extension StringProtocol {
    subscript(offset: Int) -> Character { self[index(startIndex, offsetBy: offset)] }
    subscript(range: Range<Int>) -> SubSequence {
        let startIndex = index(self.startIndex, offsetBy: range.lowerBound)
        return self[startIndex..<index(startIndex, offsetBy: range.count)]
    }
    subscript(range: ClosedRange<Int>) -> SubSequence {
        let startIndex = index(self.startIndex, offsetBy: range.lowerBound)
        return self[startIndex..<index(startIndex, offsetBy: range.count)]
    }
    subscript(range: PartialRangeFrom<Int>) -> SubSequence { self[index(startIndex, offsetBy: range.lowerBound)...] }
    subscript(range: PartialRangeThrough<Int>) -> SubSequence { self[...index(startIndex, offsetBy: range.upperBound)] }
    subscript(range: PartialRangeUpTo<Int>) -> SubSequence { self[..<index(startIndex, offsetBy: range.upperBound)] }
}

extension String: DNA {
    
    public static func random(length: Int) -> String {
        return randomString(length: length, targetLength: 0, numOfWorkers: 0)
    }
    
    private static func randomString(length: Int, targetLength: Int, numOfWorkers: Int) -> String {

        let letters : NSString = "abcdefghijklmnopqrstuvwxyz'ABCDEFGHIJKLMNOPQRSTUVWXYZ; .,?:@#$%^&*()_+=-±!0123456789\n    "
        let len = UInt32(letters.length)
        
        var randomString = ""
        
//        var repeatFlag = true
//        while repeatFlag {
            for _ in 0 ..< length {
                let rand = arc4random_uniform(len)
                var nextChar = letters.character(at: Int(rand))
                randomString += NSString(characters: &nextChar, length: 1) as String
//                if targetLength >= 0 {
//                    randomFix![randomString] = randomFix![randomString] ?? 0
//                }
//            }
//            if targetLength < 0 {
//                repeatFlag = false
//            }
//            else {
//                randomFix![randomString]! += 1
//                let randomRatio: CGFloat = CGFloat(randomFix![randomString]!) / CGFloat(targetLength)
//                let multi: CGFloat = CGFloat(numOfWorkers / targetLength) * ratio
//                repeatFlag = randomRatio * multi >= 1
//
////                print("value: char: \(randomString) : score: \(randomFix![randomString] ?? 0), randomRatio: \(randomRatio), multi: \(multi), total: \(randomRatio * multi)")
//
//                if repeatFlag {
////                    print("Stop... value: char: \(randomString) : score: \(randomFix![randomString] ?? 0), randomRatio: \(randomRatio), multi: \(multi), total: \(randomRatio * multi)")
//                    randomFix![randomString]! /= 10
//                }
//            }
        }

        return randomString
    }
    
    public static func += (lhs: inout String, rhs: String) {
        lhs = lhs + rhs
    }
    
    public static func ==(lhs: String, rhs: String) -> Bool {
        return lhs.elementsEqual(rhs)
    }
    
    public subscript(offset: Int) -> String {
        get {
            return "\(self[index(startIndex, offsetBy: offset)])"
        }
        set {
            self = (self as NSString).replacingCharacters(in: NSRange(location: offset, length: 1), with: newValue)
        }
    }
    
    public static func empty() -> String {
        return ""
    }
    
    public func length() -> Int {
        return count
    }
    
    func elementsEqual(other: String) -> Bool {
        return elementsEqual(other)
    }
    
    public func calcFitness(val: String?, best: CGFloat) -> (val: CGFloat, count: CGFloat) {
        guard let  val = val else { return (0, 0) }
        var count: CGFloat = 0.1
        
        for i in 0..<val.count {
            if self[i] == val[i] {
                count += 1
            }
        }
        let x = count / CGFloat(val.count)
        return (best * (x / best) / CGFloat(val.count), CGFloat(Int(count)))
    }
    
    public func mutate(rate: CGFloat) -> Self {
        
//        guard let val = val else { return "" }
        
        var tempVal = ""
        
        for i in 0..<length() {
            let c = self[i]
            
            let r = CGFloat.random(in: 0...1)
            
            if r < rate {
                tempVal += String.random(length: 1)
            }
            else {
                tempVal += c
            }
        }
        
        return tempVal
    }
    
    public func find(target: String, count: CGFloat) -> Bool {
        return self == target  && Int(count) == length()
    }
}
