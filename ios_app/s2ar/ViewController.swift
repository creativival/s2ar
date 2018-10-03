//
//  ViewController.swift
//  s2ar
//
//  Created by Junya Ishihara on 2018/09/03.
//  Copyright © 2018年 Junya Ishihara. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import SocketIO

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    let manager = SocketManager(socketURL: URL(string: "http://s2ar-helper.glitch.me")!, config: [.log(true), .compress])
    var settingOrigin: Bool = true
    
    var xAxisNode: SCNNode!
    var yAxisNode: SCNNode!
    var zAxisNode: SCNNode!
    var originPosition: SCNVector3!
    
    var cubeNode: SCNNode!
    var cubeNodes: [String:SCNNode] = [:]
    
    var lightNode: SCNNode!
    var backLightNode: SCNNode!
    
    var planeNode: SCNNode!
    var planeNodes: [UUID:SCNNode] = [:]
    
    var red: Int = 255
    var green: Int = 255
    var blue: Int = 255
    
    var roomId: String = "0000 0000"
    var CUBE_SIZE: Float = 0.02
    
    var timer = Timer()
    
    @IBOutlet var roomIDLabel: UILabel!
    
    @IBOutlet var togglePlanesButton: UIButton!
    
    func changeCubeSize(magnification: Float) {
        if (originPosition == nil) {
            return
        }
        self.roomIDLabel.text = " Resize x\(magnification)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            // Put your code which should be executed with a delay here
            self.roomIDLabel.text = "Connected !"
        }
        CUBE_SIZE = round(0.02 * magnification * 1000.0) / 1000.0
    }
    
    func setCube(x: Float, y: Float, z: Float) {
        if (originPosition == nil) {
            return
        }
        // 3Dモデル作成のデータ（.ply）は整数のみではなく 0.5 を含むため、setCube を 0.5 刻みで置けるように改造した。
        //小数点以下を .0 または .5 に変換
        let _x: Float = round(2.0 * x) / 2.0
        let _y: Float = round(2.0 * y) / 2.0
        let _z: Float = round(2.0 * z) / 2.0
        
        func setCubeMethod(x: Float, y: Float, z: Float) {
            let cube = SCNBox(width: CGFloat(CUBE_SIZE), height: CGFloat(CUBE_SIZE), length: CGFloat(CUBE_SIZE), chamferRadius: 0)
            cube.firstMaterial?.diffuse.contents  = UIColor(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1)
            cubeNode = SCNNode(geometry: cube)
            cubeNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
            let position = SCNVector3Make(
                originPosition.x + _x * CUBE_SIZE,
                originPosition.y + _y * CUBE_SIZE,
                originPosition.z + _z * CUBE_SIZE
            )
            cubeNode.position = position
            sceneView.scene.rootNode.addChildNode(cubeNode)
            cubeNodes[String(_x) + "_" + String(_y) + "_" + String(_z)] = cubeNode
        }
        if cubeNodes.keys.contains(String(_x) + "_" + String(_y) + "_" + String(_z)) {
            // remove cube if contains
            self.removeCube(x: _x, y: _y, z: _z)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                // set cube
                setCubeMethod(x: _x, y: _y, z: _z)
            }
        } else {
            // set cube
            setCubeMethod(x: _x, y: _y, z: _z)
        }
    }
    
    func setBox(x: Int, y: Int, z: Int, w: Int, d: Int, h: Int) {
        if (originPosition == nil) {
            return
        }
        
        for k in 0...d {
            for j in 0...h {
                for i in 0...w {
                    self.setCube(x: Float(x + i), y: Float(y + j), z: Float(z + k))
                }
            }
        }
    }
    
    func setCylinder(x: Int, y: Int, z: Int, r: Int, h: Int, a: String) {
        if (originPosition == nil) {
            return
        }
        
        switch a {
        case "x":
            for k in -r...r {
                for j in -r...r {
                    for i in 0..<h {
                        if (j * j + k * k < r * r) {
                            self.setCube(x: Float(x + i), y: Float(y + j), z: Float(z + k))
                        }
                    }
                }
            }
        case "y":
            for k in -r...r {
                for j in 0..<h {
                    for i in -r...r {
                        if (i * i + k * k < r * r) {
                            self.setCube(x: Float(x + i), y: Float(y + j), z: Float(z + k))
                        }
                    }
                }
            }
        case "z":
            for k in 0..<h {
                for j in -r...r {
                    for i in -r...r {
                        if (i * i + j * j < r * r) {
                            self.setCube(x: Float(x + i), y: Float(y + j), z: Float(z + k))
                        }
                    }
                }
            }
        default:
            break
        }
    }
    
    func setHexagon(x: Int, y: Int, z: Int, r: Int, h: Int, a: String) {
        if (originPosition == nil) {
            return
        }
        
        switch a {
        case "x":
            for k in 0...r {
                for j in 0...r {
                    for i in 0..<h {
                        if ((Double(j) <= cos(Double.pi / 6) * Double(r)) && (Double(j) <= -tan(Double.pi / 3) * Double(k) + tan(Double.pi / 3) * Double(r))) {
                            self.setCube(x: Float(x + i), y: Float(y + j), z: Float(z + k))
                            self.setCube(x: Float(x + i), y: Float(y - j), z: Float(z + k))
                            self.setCube(x: Float(x + i), y: Float(y - j), z: Float(z - k))
                            self.setCube(x: Float(x + i), y: Float(y + j), z: Float(z - k))
                        }
                    }
                }
            }
        case "y":
            for k in 0...r {
                for j in 0..<h {
                    for i in 0...r {
                        if ((Double(k) <= cos(Double.pi / 6) * Double(r)) && (Double(k) <= -tan(Double.pi / 3) * Double(i) + tan(Double.pi / 3) * Double(r))) {
                            self.setCube(x: Float(x + i), y: Float(y + j), z: Float(z + k))
                            self.setCube(x: Float(x - i), y: Float(y + j), z: Float(z + k))
                            self.setCube(x: Float(x - i), y: Float(y + j), z: Float(z - k))
                            self.setCube(x: Float(x + i), y: Float(y + j), z: Float(z - k))
                        }
                    }
                }
            }
        case "z":
            for k in 0..<h {
                for j in 0...r {
                    for i in 0...r {
                        if ((Double(j) <= cos(Double.pi / 6) * Double(r)) && (Double(j) <= -tan(Double.pi / 3) * Double(i) + tan(Double.pi / 3) * Double(r))) {
                            self.setCube(x: Float(x + i), y: Float(y + j), z: Float(z + k))
                            self.setCube(x: Float(x - i), y: Float(y + j), z: Float(z + k))
                            self.setCube(x: Float(x - i), y: Float(y - j), z: Float(z + k))
                            self.setCube(x: Float(x + i), y: Float(y - j), z: Float(z + k))
                        }
                    }
                }
            }
        default:
            break
        }
    }
    
    func setSphere(x: Int, y: Int, z: Int, r: Int) {
        if (originPosition == nil) {
            return
        }
        
        for k in -r...r {
            for j in -r...r {
                for i in -r...r {
                    if (i * i + j * j + k * k < r * r) {
                        self.setCube(x: Float(x + i), y: Float(y + j), z: Float(z + k))
                    }
                }
            }
        }
    }
    
    func setChar(x: Int, y: Int, z: Int, c: String, a: String) {
        if (originPosition == nil) {
            return
        }
        var k = 0
        let char:String! = Chars.chars[c]
        
        switch (a) {
        case "x":
            for j in 0..<8 {
                for i in 0..<8 {
                    var flag = char[char.index(char.startIndex, offsetBy: k)..<char.index(char.startIndex, offsetBy: k + 1)]
                    if (flag == "1") {
                        self.setCube(x: Float(x), y: Float(y - j), z: Float(z + i))
                    }
                    k += 1
                }
            }
        case "y":
            for j in 0..<8 {
                for i in 0..<8 {
                    var flag = char[char.index(char.startIndex, offsetBy: k)..<char.index(char.startIndex, offsetBy: k + 1)]
                    if (flag == "1") {
                        self.setCube(x: Float(x + i), y: Float(y), z: Float(z - j))
                    }
                    k += 1
                }
            }
        case "z":
            for j in 0..<8 {
                for i in 0..<8 {
                    var flag = char[char.index(char.startIndex, offsetBy: k)..<char.index(char.startIndex, offsetBy: k + 1)]
                    if (flag == "1") {
                        self.setCube(x: Float(x + i), y: Float(y - j), z: Float(z))
                    }
                    k += 1
                }
            }
        default:
            break
        }
    }
    
    func setLine(x1: Int, y1: Int, z1: Int, x2: Int, y2: Int, z2: Int) {
        if (originPosition == nil) {
            return
        }
        if !(x1 == x2 && y1 == y2 && z1 == z2) {
            var vector = [x2 - x1, y2 - y1, z2 - z1]
            var vector2 = [abs(x2 - x1), abs(y2 - y1), abs(z2 - z1)]
            var _x: Float
            var _y: Float
            var _z: Float
            
            let index:Int? = vector2.index(of: vector2.max()!)
            
            switch (index) {
            case 0:
                for i in 0...vector2[0] {
                    if (x2 > x1) {
                        //self.setCube(x: x1 + i, y: y1 + vector[1] * i / vector[0], z: z1 + vector[2] * i / vector[0])
                        _x = Float(x1 + i)
                        _y = Float(y1 + vector[1] * i / vector[0])
                        _z = Float(z1 + vector[2] * i / vector[0])
                    } else {
                        //self.setCube(x: x2 + i, y: y2 + vector[1] * i / vector[0], z: z2 + vector[2] * i / vector[0])
                        _x = Float(x2 + i)
                        _y = Float(y2 + vector[1] * i / vector[0])
                        _z = Float(z2 + vector[2] * i / vector[0])
                    }
                    if !(cubeNodes.keys.contains(String(_x) + "_" + String(_y) + "_" + String(_z))) {
                        // does notcontains key
                        self.setCube(x: _x, y: _y, z: _z)
                    }
                }
            case 1:
                for i in 0...vector2[1] {
                    if (y2 > y1) {
                        //self.setCube(x: x1 + vector[0] * i / vector[1], y: y1 + i, z: z1 + vector[2] * i / vector[1])
                        _x = Float(x1 + vector[0] * i / vector[1])
                        _y = Float(y1 + i)
                        _z = Float(z1 + vector[2] * i / vector[1])
                    } else {
                        //self.setCube(x: x2 + vector[0] * i / vector[1], y: y2 + i, z: z2 + vector[2] * i / vector[1])
                        _x = Float(x2 + vector[0] * i / vector[1])
                        _y = Float(y2 + i)
                        _z = Float(z2 + vector[2] * i / vector[1])
                    }
                    if !(cubeNodes.keys.contains(String(_x) + "_" + String(_y) + "_" + String(_z))) {
                        // does notcontains key
                        self.setCube(x: _x, y: _y, z: _z)
                    }
                }
            case 2:
                for i in 0...vector2[2] {
                    if (z2 > z1) {
                        //self.setCube(x: x1 + vector[0] * i / vector[2], y: y1 + vector[1] * i / vector[2], z: z1 + i)
                        _x = Float(x1 + vector[0] * i / vector[2])
                        _y = Float(y1 + vector[1] * i / vector[2])
                        _z = Float(z1 + i)
                    } else {
                        //self.setCube(x: x2 + vector[0] * i / vector[2], y: y2 + vector[1] * i / vector[2], z: z2 + i)
                        _x = Float(x2 + vector[0] * i / vector[2])
                        _y = Float(y2 + vector[1] * i / vector[2])
                        _z = Float(z2 + i)
                    }
                    if !(cubeNodes.keys.contains(String(_x) + "_" + String(_y) + "_" + String(_z))) {
                        // does notcontains key
                        self.setCube(x: _x, y: _y, z: _z)
                    }
                }
            default:
                break
            }
        }
    }
    
    func setRoof(_x: Int, _y: Int, _z: Int, w: Int, d: Int, h: Int, a: String) {
        if (originPosition == nil) {
            return
        }
        
        switch (a) {
        case "x":
            if (w % 2 == 0) {
                if (abs(h) <= w / 2) {
                    for j in 0..<w {
                        let y:Int
                        if (j < w / 2) {
                            y = _y + 2 * (h - 1) * j / (w - 2)
                        } else {
                            y = _y - 2 * (h - 1) * (j - w + 1) / (w - 2)
                        }
                        for i in _x..<(_x + d) {
                            self.setCube(x: Float(i), y: Float(y), z: Float(_z + j))
                        }
                    }
                } else {
                    for j in 0..<h {
                        for i in _z..<(_z + d) {
                            self.setCube(x: Float(i), y: Float(_y + j), z: Float((_z + (w - 2) * j / (2 * (h - 1)))))
                        }
                        for i in _x..<(_x + d) {
                            self.setCube(x: Float(i), y: Float(_y + j), z: Float((_z - (w - 2) * j / (2 * (h - 1)) + w - 1)))
                        }
                    }
                }
            } else {
                if (abs(h) <= (w + 1) / 2) {
                    for j in 0..<w {
                        let y:Int
                        if (j < w / 2) {
                            y = _y + 2 * (h - 1) * j / (w - 1)
                        } else {
                            y = _y - 2 * (h - 1) * (j - w + 1) / (w - 1)
                        }
                        for i in _x..<(_x + d) {
                            self.setCube(x: Float(i), y: Float(y), z: Float(_z + j))
                        }
                    }
                } else {
                    for j in 0..<h {
                        for i in _x..<(_x + d) {
                            self.setCube(x: Float(i), y: Float(_y + j), z: Float((_z + (w - 1) * j / (2 * (h - 1)))))
                        }
                        for i in _x..<(_x + d) {
                            self.setCube(x: Float(i), y: Float(_y + j), z: Float((_z - (w - 1) * (j - 2 * h + 2) / (2 * (h - 1)))))
                        }
                    }
                }
            }
        case "y":
            if (w % 2 == 0) {
                if (abs(h) <= w / 2) {
                    for j in 0..<w {
                        let z:Int
                        if (j < w / 2) {
                            z = _z + 2 * (h - 1) * j / (w - 2)
                        } else {
                            z = _z - 2 * (h - 1) * (j - w + 1) / (w - 2)
                        }
                        for i in _y..<(_y + d) {
                            self.setCube(x: Float(_x + j), y: Float(i), z: Float(z))
                        }
                    }
                } else {
                    for j in 0..<h {
                        for i in _y..<(_y + d) {
                            self.setCube(x: Float((_x + (w - 2) * j / (2 * (h - 1)))), y: Float(i), z: Float(_z + j))
                        }
                        for i in _y..<(_y + d) {
                            self.setCube(x: Float((_x - (w - 2) * j / (2 * (h - 1)) + w - 1)), y: Float(i), z: Float(_z + j))
                        }
                    }
                }
            } else {
                if (abs(h) <= (w + 1) / 2) {
                    for j in 0..<w {
                        let z:Int
                        if (j < w / 2) {
                            z = _z + 2 * (h - 1) * j / (w - 1)
                        } else {
                            z = _z - 2 * (h - 1) * (j - w + 1) / (w - 1)
                        }
                        for i in _y..<(_y + d) {
                            self.setCube(x: Float(_x + j), y: Float(i), z: Float(z))
                        }
                    }
                } else {
                    for j in 0..<h {
                        for i in _y..<(_y + d) {
                            self.setCube(x: Float((_x + (w - 1) * j / (2 * (h - 1)))), y: Float(i), z: Float(_z + j))
                        }
                        for i in _y..<(_y + d) {
                            self.setCube(x: Float((_x - (w - 1) * (j - 2 * h + 2) / (2 * (h - 1)))), y: Float(i), z: Float(_z + j))
                        }
                    }
                }
            }
        case "z":
            if (w % 2 == 0) {
                if (abs(h) <= w / 2) {
                    for j in 0..<w {
                        let y:Int
                        if (j < w / 2) {
                            y = _y + 2 * (h - 1) * j / (w - 2)
                        } else {
                            y = _y - 2 * (h - 1) * (j - w + 1) / (w - 2)
                        }
                        for i in _z..<(_z + d) {
                            self.setCube(x: Float(_x + j), y: Float(y), z: Float(i))
                        }
                    }
                } else {
                    for j in 0..<h {
                        for i in _z..<(_z + d) {
                            self.setCube(x: Float((_x + (w - 2) * j / (2 * (h - 1)))), y: Float(_y + j), z: Float(i))
                        }
                        for i in _z..<(_z + d) {
                            self.setCube(x: Float((_x - (w - 2) * j / (2 * (h - 1)) + w - 1)), y: Float(_y + j), z: Float(i))
                        }
                    }
                }
            } else {
                if (abs(h) <= (w + 1) / 2) {
                    for j in 0..<w {
                        let y:Int
                        if (j < w / 2) {
                            y = _y + 2 * (h - 1) * j / (w - 1)
                        } else {
                            y = _y - 2 * (h - 1) * (j - w + 1) / (w - 1)
                        }
                        for i in _z..<(_z + d) {
                            self.setCube(x: Float(_x + j), y: Float(y), z: Float(i))
                        }
                    }
                } else {
                    for j in 0..<h {
                        for i in _x..<(_x + d) {
                            self.setCube(x: Float((_x + (w - 1) * j / (2 * (h - 1)))), y: Float(_y + j), z: Float(i))
                        }
                        for i in _x..<(_x + d) {
                            self.setCube(x: Float((_x - (w - 1) * (j - 2 * h + 2) / (2 * (h - 1)))), y: Float(_y + j), z: Float(i))
                        }
                    }
                }
            }
        default:
            break
        }
    }
    
    func polygonFileFormat(x: Int, y: Int, z: Int, ply_file: String) {
        if (originPosition == nil) {
            return
        }
        
        let roop: Int
        var ply2 = [[String]]()
        
        func createModel() throws {
            if ply2.count == 0 {
                throw NSError(domain: "error message", code: -1, userInfo: nil)
            }
            var vertex1: [String]
            var vertex2: [String]
            var vertex3: [String]
            var _x: Float
            var _y: Float
            var _z: Float
            for i in 0 ..< roop {
                vertex1 = ply2[4 * i]
                vertex2 = ply2[4 * i + 1]
                vertex3 = ply2[4 * i + 2]
                self.setColor(r: Int(vertex1[3])!, g: Int(vertex1[4])!, b: Int(vertex1[5])!)
                if vertex1[0] == vertex2[0] && vertex2[0] == vertex3[0] {// y-z plane
                    if vertex1[1] == vertex2[1] {
                        _x = Float(x) + Float(vertex1[0])!
                        _y = Float(y) + Float(vertex1[2])!
                        _z = Float(z) - Float(vertex1[1])!
                        if !(cubeNodes.keys.contains(String(_x) + "_" + String(_y) + "_" + String(_z))) {
                            // does not contains key
                            self.setCube(x: _x, y: _y, z: _z)
                        }
                    } else {
                        _x = Float(x) + Float(vertex1[0])! - 1.0
                        _y = Float(y) + Float(vertex1[2])!
                        _z = Float(z) - Float(vertex1[1])!
                        if !(cubeNodes.keys.contains(String(_x) + "_" + String(_y) + "_" + String(_z))) {
                            // does notcontains key
                            self.setCube(x: _x, y: _y, z: _z)
                        }
                    }
                } else if vertex1[1] == vertex2[1] && vertex2[1] == vertex3[1] {//z-x plane
                    if vertex1[2] == vertex2[2] {
                        _x = Float(x) + Float(vertex1[0])!
                        _y = Float(y) + Float(vertex1[2])!
                        _z = Float(z) - Float(vertex1[1])!
                        if !(cubeNodes.keys.contains(String(_x) + "_" + String(_y) + "_" + String(_z))) {
                            // does notcontains key
                            self.setCube(x: _x, y: _y, z: _z)
                        }
                    } else {
                        _x = Float(x) + Float(vertex1[0])!
                        _y = Float(y) + Float(vertex1[2])!
                        _z = Float(z) - Float(vertex1[1])! + 1.0
                        if !(cubeNodes.keys.contains(String(_x) + "_" + String(_y) + "_" + String(_z))) {
                            // does notcontains key
                            self.setCube(x: _x, y: _y, z: _z)
                        }
                    }
                } else {//x-y plane
                    if vertex1[0] == vertex2[0] {
                        _x = Float(x) + Float(vertex1[0])!
                        _y = Float(y) + Float(vertex1[2])!
                        _z = Float(z) - Float(vertex1[1])!
                        if !(cubeNodes.keys.contains(String(_x) + "_" + String(_y) + "_" + String(_z))) {
                            // does notcontains key
                            self.setCube(x: _x, y: _y, z: _z)
                        }
                    } else {
                        _x = Float(x) + Float(vertex1[0])!
                        _y = Float(y) + Float(vertex1[2])! - 1.0
                        _z = Float(z) - Float(vertex1[1])!
                        if !(cubeNodes.keys.contains(String(_x) + "_" + String(_y) + "_" + String(_z))) {
                            // does notcontains key
                            self.setCube(x: _x, y: _y, z: _z)
                        }
                    }
                }
            }
        }
        
        if ply_file.contains("ply") {
            // Read ply file from iTunes File Sharing
            if let dir = FileManager.default.urls( for: .documentDirectory, in: .userDomainMask ).first {
                let path_ply_file = dir.appendingPathComponent( ply_file )
                do {
                    let ply = try String( contentsOf: path_ply_file, encoding: String.Encoding.utf8 )
                    var plys = ply.components(separatedBy: "\r\n")
                    if plys.count == 1 {
                        plys = ply.components(separatedBy: "\n")
                    }
                    if plys.count == 1 {
                        plys = ply.components(separatedBy: "\r")
                    }
                    if Int(plys[4].components(separatedBy: " ")[2]) != nil {
                        roop = Int(plys[4].components(separatedBy: " ")[2])! / 4
                        for i in 0 ..< 4 * roop {
                            ply2.append(plys[14 + i].components(separatedBy: " "))
                        }
                        try createModel()
                    } else {
                        //error message
                        self.roomIDLabel.text = "Incorrect format"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            // Put your code which should be executed with a delay here
                            self.roomIDLabel.text = "Connected !"
                        }
                    }
                } catch {
                    //error message
                    self.roomIDLabel.text = "Not such a file"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        // Put your code which should be executed with a delay here
                        self.roomIDLabel.text = "Connected !"
                    }
                }
            }
        } else {
            //read from scratch
            do {
                let plys = ply_file.components(separatedBy: " ")
                var tempArray: [String] = []
                roop = plys.count / 24
                for i in 0 ..< 4 * plys.count / 6 {
                    for j in 0 ..< 6 {
                        tempArray.append(plys[6 * i + j])
                    }
                    ply2.append(tempArray)
                    tempArray = []
                }
                try createModel()
            } catch {
                //error message
                self.roomIDLabel.text = "Incorrect format"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    // Put your code which should be executed with a delay here
                    self.roomIDLabel.text = "Connected !"
                }
            }
        }
    }
    
    func animation(x: Int, y: Int, z: Int, differenceX: Int, differenceY: Int, differenceZ: Int, time: Double, times: Int, files: String) {
        if (originPosition == nil) {
            return
        }
        
        let plys = files.components(separatedBy: ",")
        if plys[0].contains(".ply") || plys.count > 3 {
            if let dir = FileManager.default.urls( for: .documentDirectory, in: .userDomainMask ).first {
                do {
                    for i in 0 ..< plys.count {
                        let path_ply_file = dir.appendingPathComponent( plys[i] )
                        _ = try String( contentsOf: path_ply_file, encoding: String.Encoding.utf8 )
                    }
                    var i = 0
                    timer = Timer.scheduledTimer(withTimeInterval: time, repeats: true, block: { (timer) in
                        self.polygonFileFormat(x: x + i * differenceX, y: y + i * differenceY, z: z + i * differenceZ, ply_file: plys[i % plys.count])
                        DispatchQueue.main.asyncAfter(deadline: .now() + time * 0.8) {
                            // Put your code which should be executed with a delay here
                            self.reset()
                        }
                        i += 1
                        if (i >= times) {
                            timer.invalidate()
                        }
                    })
                } catch {
                    //error message
                    self.roomIDLabel.text = "Not such a file"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        // Put your code which should be executed with a delay here
                        self.roomIDLabel.text = "Connected !"
                    }
                }
            }
        } else {
            //error message
            self.roomIDLabel.text = "Incorrect files"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                // Put your code which should be executed with a delay here
                self.roomIDLabel.text = "Connected !"
            }
        }
    }
    
    func map(map_data: String, width: Int, height: Int, magnification: Float, r1: Int, g1: Int, b1: Int, r2: Int, g2: Int, b2: Int, upward: Int) {
        if (originPosition == nil) {
            return
        }
        self.roomIDLabel.text = "Mapping..."
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Put your code which should be executed with a delay here
            self.roomIDLabel.text = "Connected !"
        }
        var map2 = [[String]]()
        var map3 = [[String]]()
        var map4 = [[Int]]()
        //map4.append([Int]())
        var maps: [String] = []
        var _maps: [String] = []
        var tempArray: [String] = []
        var tempArray2: [Int] = []
        
        func heightSetColor(y: Int, minY: Int, maxY: Int) {
            var _r: Int
            var _g: Int
            var _b: Int
            if minY == maxY {
                _r = r2
                _g = g2
                _b = b2
            } else {
                _r = Int(r1 + (y - minY) * (r2 - r1) / (maxY - minY))
                _g = Int(g1 + (y - minY) * (g2 - g1) / (maxY - minY))
                _b = Int(b1 + (y - minY) * (b2 - b1) / (maxY - minY))
                _r = _r > r2 ? r2 : _r
                _g = _g > g2 ? g2 : _g
                _b = _b > b2 ? b2 : _b
            }
            setColor(r: _r, g: _g, b: _b)
        }
        
        func drawMap(i: Int, j: Int, elevation: Int, gap: Int, minY: Int, maxY: Int, upward: Int) {
            let _x = Int(height / 2) - i
            let _y = elevation
            let _z = j - Int(width / 2)
            if _y > 0 {
                heightSetColor(y: _y, minY: minY, maxY: maxY)
                self.setCube(x: Float(_x), y: Float(_y + upward), z: Float(_z))
                if gap > 1 {
                    for k in 1 ... gap - 1 {
                        heightSetColor(y: _y - k, minY: minY, maxY: maxY)
                        self.setCube(x: Float(_x), y: Float(_y - k + upward), z: Float(_z))
                    }
                }
            } else if _y < 0{
                heightSetColor(y: -_y, minY: -minY, maxY: -maxY)
                self.setCube(x: Float(_x), y: Float(_y + 1 + upward), z: Float(_z))
                if gap > 1 {
                    for k in 1 ... gap - 1 {
                        heightSetColor(y: _y - k, minY: minY, maxY: maxY)
                        self.setCube(x: Float(_x), y: Float(_y + 1 + k + upward), z: Float(_z))
                    }
                }
            }
        }
        
        func mapping() throws {
            if map2.count != height || map2[0].count != width {
                throw NSError(domain: "error message", code: -1, userInfo: nil)
            }
            var elevation: Int
            var gap: Int // to fill the gap
            var maxY: Int
            var minY: Int
            //前後にスペースが入っていたら消す。
            for i in 0 ..< height {
                for j in 0 ..< width {
                    tempArray.append(map2[i][j].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                }
                map3.append(tempArray)
                tempArray = []
            }
            //数字以外の文字が入っていたときの処理
            for i in 0 ..< height {
                for j in 0 ..< width {
                    if let num: Float = Float(map3[i][j]) {
                        tempArray2.append(Int(ceil(num * magnification)))
                    } else {
                        tempArray2.append(0)
                    }
                }
                map4.append(tempArray2)
                tempArray2 = []
            }
            //y の最大値、最小値
            minY = map4[0][0]
            maxY = map4[0][0]
            
            for i in 0 ..< height {
                for j in 0 ..< width {
                    elevation = map4[i][j]
                    if minY > map4[i][j] {
                        minY = map4[i][j]
                    }
                    if maxY < map4[i][j] {
                        maxY = map4[i][j]
                    }
                    if elevation > 0 {
                        // Calculate gaps
                        if height == 1 {
                            if j == 0 {
                                gap = elevation - [map4[i][j + 1]].min()!
                            } else if j == width - 1 {
                                gap = elevation - [map4[i][j - 1]].min()!
                            } else {
                                gap = elevation - [map4[i][j - 1], map4[i][j + 1]].min()!
                            }
                        } else if i == 0 {
                            if j == 0 {
                                if width == 1 {
                                    gap = elevation - [map4[i + 1][j]].min()!
                                } else {
                                    gap = elevation - [map4[i + 1][j], map4[i][j + 1]].min()!
                                }
                            } else if j == width - 1 {
                                gap = elevation - [map4[i + 1][j], map4[i][j - 1]].min()!
                            } else {
                                gap = elevation - [map4[i + 1][j], map4[i][j - 1], map4[i][j + 1]].min()!
                            }
                        } else if i == height - 1 {
                            if j == 0 {
                                if width == 1 {
                                    gap = elevation - [map4[i - 1][j]].min()!
                                } else {
                                    gap = elevation - [map4[i - 1][j], map4[i][j + 1]].min()!
                                }
                            } else if j == width - 1 {
                                gap = elevation - [map4[i - 1][j], map4[i][j - 1]].min()!
                            } else {
                                gap = elevation - [map4[i - 1][j], map4[i][j - 1], map4[i][j + 1]].min()!
                            }
                        } else {
                            if j == 0 {
                                if width == 1 {
                                    gap = elevation - [map4[i - 1][j], map4[i + 1][j]].min()!
                                } else {
                                    gap = elevation - [map4[i - 1][j], map4[i + 1][j], map4[i][j + 1]].min()!
                                }
                            } else if j == width - 1 {
                                gap = elevation - [map4[i - 1][j], map4[i + 1][j], map4[i][j - 1]].min()!
                            } else {
                                gap = elevation - [map4[i - 1][j], map4[i + 1][j], map4[i][j - 1], map4[i][j + 1]].min()!
                            }
                        }
                    } else {
                        // Calculate gaps
                        if height == 1 {
                            if j == 0 {
                                gap = -elevation + [map4[i][j + 1]].max()!
                            } else if j == width - 1 {
                                gap = -elevation + [map4[i][j - 1]].max()!
                            } else {
                                gap = -elevation + [map4[i][j - 1], map4[i][j + 1]].max()!
                            }
                        } else if i == 0 {
                            if j == 0 {
                                if width == 1 {
                                    gap = -elevation + [map4[i + 1][j]].max()!
                                } else {
                                    gap = -elevation + [map4[i + 1][j], map4[i][j + 1]].max()!
                                }
                            } else if j == width - 1 {
                                gap = -elevation + [map4[i + 1][j], map4[i][j - 1]].max()!
                            } else {
                                gap = -elevation + [map4[i + 1][j], map4[i][j - 1], map4[i][j + 1]].max()!
                            }
                        } else if i == height - 1 {
                            if j == 0 {
                                if width == 1 {
                                    gap = -elevation + [map4[i - 1][j]].max()!
                                } else {
                                    gap = -elevation + [map4[i - 1][j], map4[i][j + 1]].max()!
                                }
                            } else if j == width - 1 {
                                gap = -elevation + [map4[i - 1][j], map4[i][j - 1]].max()!
                            } else {
                                gap = -elevation + [map4[i - 1][j], map4[i][j - 1], map4[i][j + 1]].max()!
                            }
                        } else {
                            if j == 0 {
                                if width == 1 {
                                    gap = -elevation + [map4[i - 1][j], map4[i + 1][j]].max()!
                                } else {
                                    gap = -elevation + [map4[i - 1][j], map4[i + 1][j], map4[i][j + 1]].max()!
                                }
                            } else if j == width - 1 {
                                gap = -elevation + [map4[i - 1][j], map4[i + 1][j], map4[i][j - 1]].max()!
                            } else {
                                gap = -elevation + [map4[i - 1][j], map4[i + 1][j], map4[i][j - 1], map4[i][j + 1]].max()!
                            }
                        }
                        
                    }
                    drawMap(i: i, j: j, elevation: elevation, gap: gap, minY: minY, maxY: maxY, upward: upward)
                }
            }
        }
        
        if map_data.contains("csv") || map_data.contains("txt") {
            // Read ply file from iTunes File Sharing
            if let dir = FileManager.default.urls( for: .documentDirectory, in: .userDomainMask ).first {
                let path_csv_file = dir.appendingPathComponent( map_data )
                do {
                    let csv = try String( contentsOf: path_csv_file, encoding: String.Encoding.utf8 )
                    maps = csv.components(separatedBy: "\r\n")
                    if maps.count == 1 {
                        maps = csv.components(separatedBy: "\n")
                    }
                    if maps.count == 1 {
                        maps = csv.components(separatedBy: "\r")
                    }
                    if maps.count == 1 { // from Web地理院地図（http://maps.gsi.go.jp）
                        _maps = maps[0].components(separatedBy: ",")
                        for i in 0 ..< height {
                            for j in 0 ..< width {
                                tempArray.append(_maps[i * width + j])
                            }
                            map2.append(tempArray)
                            tempArray = []
                        }
                        try mapping()
                    } else if maps.count >= height { // from Web地形自動生成（http://www.bekkoame.ne.jp/ro/kami/LandMaker/LandMaker.html） or self made map
                        if maps[0].contains("map") || maps[0].contains("Map") {
                           maps.removeFirst()
                        }
                        for i in 0 ..< height {
                            if maps[i].contains(",") {
                                map2.append(maps[i].components(separatedBy: ","))
                            } else if maps[i].contains("\t") {
                                map2.append(maps[i].components(separatedBy: "\t"))
                            } else {
                                // replace all
                                while true {
                                    if let range = maps[i].range(of: "  ") {
                                        maps[i].replaceSubrange(range, with: " ")
                                    } else {
                                        break
                                    }
                                }
                                map2.append(maps[i].components(separatedBy: " "))
                            }
                        }
                        try mapping()
                    } else {
                        //error message
                        self.roomIDLabel.text = "Incorrect format"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            // Put your code which should be executed with a delay here
                            self.roomIDLabel.text = "Connected !"
                        }
                    }
                } catch {
                    //error message
                    self.roomIDLabel.text = "Not such a file"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        // Put your code which should be executed with a delay here
                        self.roomIDLabel.text = "Connected !"
                    }
                }
            }
        } else {
            //Read from Scratch
            var _map_data = map_data
            // replace all for Web地形自動生成
            while true {
                if let range = _map_data.range(of: "  ") {
                    _map_data.replaceSubrange(range, with: " ")
                } else {
                    break
                }
            }
            while true {
                if let range = _map_data.range(of: "\t ") {
                    _map_data.replaceSubrange(range, with: "\t")
                } else {
                    break
                }
            }
            maps = _map_data.components(separatedBy: " ")
            if maps[0].contains("map") || maps[0].contains("Map") {
                maps.removeFirst()
                for i in 0 ..< height {
                    if maps[i].contains(",") {
                        map2.append(maps[i].components(separatedBy: ","))
                    } else if maps[i].contains("\t") {
                        map2.append(maps[i].components(separatedBy: "\t"))
                    } else {
                        // replace all
                        while true {
                            if let range = maps[i].range(of: "  ") {
                                maps[i].replaceSubrange(range, with: " ")
                            } else {
                                break
                            }
                        }
                        map2.append(maps[i].components(separatedBy: " "))
                    }
                }
                do {
                    try mapping()
                } catch {
                    //error message
                    self.roomIDLabel.text = "Incorrect format"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        // Put your code which should be executed with a delay here
                        self.roomIDLabel.text = "Connected !"
                    }
                }
            } else {
                var k = 0 // 空要素が含まれている時の処理
                if maps.count >= width * height {
                    for i in 0 ..< height {
                        for j in 0 ..< width {
                            if maps[i * width + j + k] == "" {
                                k += 1
                                tempArray.append(maps[i * width + j + k])
                            } else {
                                tempArray.append(maps[i * width + j + k])
                            }
                        }
                        map2.append(tempArray)
                        tempArray = []
                    }
                    do {
                        try mapping()
                    } catch {
                        //error message
                        self.roomIDLabel.text = "Incorrect format"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            // Put your code which should be executed with a delay here
                            self.roomIDLabel.text = "Connected !"
                        }
                    }
                } else {
                    //error message
                    self.roomIDLabel.text = "Incorrect format"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        // Put your code which should be executed with a delay here
                        self.roomIDLabel.text = "Connected !"
                    }
                }
            }
        }
    }
    
    func pin(pin_data: String, width: Int, height: Int, magnification: Float, up_left_latitude: Float, up_left_longitude: Float, down_right_latitude: Float, down_right_longitude: Float, step: Int) {
        if (originPosition == nil) {
            return
        }
        self.roomIDLabel.text = "Standing pins..."
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Put your code which should be executed with a delay here
            self.roomIDLabel.text = "Connected !"
        }
        
        var pins2: [[String]] = [[String]]()
        var pins3: [[String]] = [[String]]()
        var pins4: [[Float]] = [[Float]]()
        var pins: [String] = []
        var tempArray: [String] = []
        var tempArray2: [Float] = []
        
        func standPins(i: Int, j: Int, elevation: Int, magnification: Float, step: Int) {
            let _x1 = Int(height / 2) - j
            let _y1 = 0
            let _z1 = i - Int(width / 2) + step
            let _x2 = Int(height / 2) - j
            let _y2 = Int(Float(elevation) * magnification)
            let _z2 = i - Int(width / 2) + step
            self.setLine(x1: _x1, y1: _y1, z1: _z1, x2: _x2, y2: _y2, z2: _z2)
            //self.setSphere(x: _x2, y: _y2, z: _z2, r: 2)
        }
        
        func pinning() throws {
            if pins2.count < 2 || pins2[0].count < 3 || Int(pins2[0][0]) == nil  {
                throw NSError(domain: "error message", code: -1, userInfo: nil)
            }
            //前後にスペースが入っていたら消す。
            for i in 0 ..< pins2.count {
                if pins2[i][0] != ""{
                    for j in 0 ..< 3 {
                        tempArray.append(pins2[i][j].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                    }
                    pins3.append(tempArray)
                    tempArray = []            }
            }
            //数字以外の文字が入っていたときの処理
            for i in 0 ..< pins3.count {
                for j in 0 ..< 3 {
                    if let num: Float = Float(pins3[i][j]) {
                        tempArray2.append(num)
                    } else {
                        tempArray2.append(0.0)
                    }
                }
                pins4.append(tempArray2)
                tempArray2 = []
            }
            
            self.setColor(r: Int(pins4[0][0]), g: Int(pins4[0][1]), b: Int(pins4[0][2]))
            for k in 1 ..< pins4.count {
                let i = Int(Float(width) * (pins4[k][1] - up_left_longitude) / (down_right_longitude - up_left_longitude))
                let j = height - Int(Float(height) * (pins4[k][0] - down_right_latitude) / (up_left_latitude - down_right_latitude))
                let elevation = Int(pins4[k][2])
                standPins(i: i, j: j, elevation: elevation, magnification: magnification, step: step)
            }
        }
        
        if pin_data.contains("csv") || pin_data.contains("txt") {
            // Read ply file from iTunes File Sharing
            if let dir = FileManager.default.urls( for: .documentDirectory, in: .userDomainMask ).first {
                let path_csv_file = dir.appendingPathComponent( pin_data )
                do {
                    let csv = try String( contentsOf: path_csv_file, encoding: String.Encoding.utf8 )
                    pins = csv.components(separatedBy: "\r\n")
                    if pins.count == 1 {
                        pins = csv.components(separatedBy: "\n")
                    }
                    if pins.count == 1 {
                        pins = csv.components(separatedBy: "\r")
                    }
                    if pins.count >= 3 && (pins[0].contains("pin") || pins[0].contains("Pin")) {
                        pins.removeFirst()
                        for i in 0 ..< pins.count {
                            if pins[i].contains(",") {
                                pins2.append(pins[i].components(separatedBy: ","))
                            } else if pins[i].contains("\t") {
                                pins2.append(pins[i].components(separatedBy: "\t"))
                            } else {
                                pins2.append(pins[i].components(separatedBy: " "))
                            }
                        }
                        do {
                            try pinning()
                        } catch {
                            //error message
                            self.roomIDLabel.text = "Incorrect format"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                // Put your code which should be executed with a delay here
                                self.roomIDLabel.text = "Connected !"
                            }
                        }
                    } else {
                        //error message
                        self.roomIDLabel.text = "Incorrect format"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            // Put your code which should be executed with a delay here
                            self.roomIDLabel.text = "Connected !"
                        }
                    }
                } catch {
                    //error message
                    self.roomIDLabel.text = "Not such a file"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        // Put your code which should be executed with a delay here
                        self.roomIDLabel.text = "Connected !"
                    }
                }
            }
        } else {
            //Read from Scratch
            pins = pin_data.components(separatedBy: " ")
            if pins.count >= 3 && (pins[0].contains("pin") || pins[0].contains("Pin")) {
                pins.removeFirst()
                if pins[0].contains(",") || pins[0].contains("\t") {
                    for i in 0 ..< pins.count {
                        if pins[i].contains(",") {
                            pins2.append(pins[i].components(separatedBy: ","))
                        } else {
                            pins2.append(pins[i].components(separatedBy: "\t"))
                        }
                    }
                } else {
                    if pins.count % 3 == 0 {
                        for i in 0 ..< pins.count / 3 {
                            for j in 0 ..< 3 {
                                tempArray.append(pins[3 * i + j])
                            }
                            pins2.append(tempArray)
                            tempArray = []
                        }
                    } else {
                        //error message
                        self.roomIDLabel.text = "Incorrect format"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            // Put your code which should be executed with a delay here
                            self.roomIDLabel.text = "Connected !"
                        }
                    }
                }
                do {
                    try pinning()
                } catch {
                    //error message
                    self.roomIDLabel.text = "Incorrect format"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        // Put your code which should be executed with a delay here
                        self.roomIDLabel.text = "Connected !"
                    }
                }
            } else {
                //error message
                self.roomIDLabel.text = "Incorrect format"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    // Put your code which should be executed with a delay here
                    self.roomIDLabel.text = "Connected !"
                }
            }
        }
    }
    
    func molecular_structure(x: Double, y: Double, z: Double, magnification: Double, mld_file: String) {
        if (originPosition == nil) {
            return
        }
        var position = [[String]]()
        var line = [[String]]()
        var mlds: [String] = []
        
        func createStructure() throws {
            if mlds.count < 5 || Int(mlds[1]) == nil {
                throw NSError(domain: "error message", code: -1, userInfo: nil)
            }
            var _x: Int
            var _y: Int
            var _z: Int
            var _r: Int
            var _x1: Int
            var _y1: Int
            var _z1: Int
            var _x2: Int
            var _y2: Int
            var _z2: Int
            
            let roop1: Int = Int(mlds[1])!
            for i in 0 ..< roop1 {
                position.append(mlds[2 + i].components(separatedBy: ","))
            }
            let roop2: Int = Int(mlds[2 + roop1])!
            for i in 0 ..< roop2 {
                line.append(mlds[3 + roop1 + i].components(separatedBy: ","))
            }
            for i in 0 ..< roop1 {
                switch (position[i][3]) {
                case "1": //Hydrogen 水素
                    self.setColor(r: 255, g: 255, b: 255)
                case "5": //Boron ホウ素
                    self.setColor(r: 245, g: 245, b: 220)
                case "6": //Carbon 炭素
                    self.setColor(r: 0, g: 0, b: 0)
                case "7": //Nitrogen 窒素
                    self.setColor(r: 0, g: 0, b: 255)
                case "8": //Oxygen 酸素
                    self.setColor(r: 255, g: 0, b: 0)
                case "15": //Phosphorus リン
                    self.setColor(r: 255, g: 0, b: 255)
                case "16": //Sulfur 硫黄
                    self.setColor(r: 255, g: 255, b: 0)
                case "9": //Fluorine フッ素 ハロゲン
                    self.setColor(r: 0, g: 255, b: 255)
                case "17": //Chlorine 塩素 ハロゲン
                    self.setColor(r: 0, g: 255, b: 255)
                case "35": //Bromine 臭素 ハロゲン
                    self.setColor(r: 0, g: 255, b: 255)
                case "53": //Iodine ヨウ素 ハロゲン
                    self.setColor(r: 0, g: 255, b: 255)
                case "85": //Astatine アスタチン ハロゲン
                    self.setColor(r: 0, g: 255, b: 255)
                case "11": //Sodium ナトリウム
                    self.setColor(r: 192, g: 192, b: 192)
                case "12": //Magnesium マグネシウム
                    self.setColor(r: 192, g: 192, b: 192)
                case "13": //Alminium アルミニウム
                    self.setColor(r: 192, g: 192, b: 192)
                case "14": //Silicon ケイ素
                    self.setColor(r: 192, g: 192, b: 192)
                case "19": //Potassium カリウム
                    self.setColor(r: 192, g: 192, b: 192)
                case "20": //Calcium カルシウム
                    self.setColor(r: 192, g: 192, b: 192)
                case "24": //Chromium クロム
                    self.setColor(r: 192, g: 192, b: 192)
                case "25": //Manganese マンガン
                    self.setColor(r: 192, g: 192, b: 192)
                case "26": //Iron 鉄
                    self.setColor(r: 192, g: 192, b: 192)
                case "27": //Cobalt コバルト
                    self.setColor(r: 192, g: 192, b: 192)
                case "28": //Nickel ニッケル
                    self.setColor(r: 192, g: 192, b: 192)
                case "29": //Copper 銅
                    self.setColor(r: 192, g: 192, b: 192)
                case "30": //Zinc 亜鉛
                    self.setColor(r: 192, g: 192, b: 192)
                case "47": //Silver 銀
                    self.setColor(r: 192, g: 192, b: 192)
                case "48": //Cadmium カドミウム
                    self.setColor(r: 192, g: 192, b: 192)
                case "79": //Gold 金
                    self.setColor(r: 192, g: 192, b: 192)
                default:
                    self.setColor(r: 192, g: 192, b: 192)
                    break
                }
                _x = Int(x + Double(position[i][0])! * magnification)
                _y = Int(y + Double(position[i][1])! * magnification)
                _z = Int(z + Double(position[i][2])! * magnification)
                _r = Int(0.5 * magnification)
                if _r < 3 {
                    _r = 3
                }
                self.setSphere(x: _x, y: _y, z: _z, r: _r)
            }
            self.setColor(r: 127, g: 127, b: 127)
            for j in 0 ..< roop2 {
                _x1 = Int(x + Double(position[Int(line[j][0])! - 1][0])! * magnification)
                _y1 = Int(y + Double(position[Int(line[j][0])! - 1][1])! * magnification)
                _z1 = Int(z + Double(position[Int(line[j][0])! - 1][2])! * magnification)
                _x2 = Int(x + Double(position[Int(line[j][1])! - 1][0])! * magnification)
                _y2 = Int(y + Double(position[Int(line[j][1])! - 1][1])! * magnification)
                _z2 = Int(z + Double(position[Int(line[j][1])! - 1][2])! * magnification)
                self.setLine(x1: _x1, y1: _y1, z1: _z1, x2: _x2, y2: _y2, z2: _z2)
            }
        }
        
        if mld_file.contains("mld") || mld_file.contains("csv") || mld_file.contains("txt") {
            // Read ply file from iTunes File Sharing
            if let dir = FileManager.default.urls( for: .documentDirectory, in: .userDomainMask ).first {
                let path_mld_file = dir.appendingPathComponent( mld_file )
                do {
                    let mld = try String( contentsOf: path_mld_file, encoding: String.Encoding.utf8 )
                    mlds = mld.components(separatedBy: "\r\n")
                    if mlds.count == 1 {
                        mlds = mld.components(separatedBy: "\n")
                    }
                    if mlds.count == 1 {
                        mlds = mld.components(separatedBy: "\r")
                    }
                    do {
                        try createStructure()
                    } catch {
                        //error message
                        self.roomIDLabel.text = "Incorrect format"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            // Put your code which should be executed with a delay here
                            self.roomIDLabel.text = "Connected !"
                        }
                    }
                } catch {
                    //error message
                    self.roomIDLabel.text = "Not such a file"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        // Put your code which should be executed with a delay here
                        self.roomIDLabel.text = "Connected !"
                    }
                }
            }
        } else {
            //Read from Scratch
            mlds = mld_file.components(separatedBy: " ")
            do {
                try createStructure()
            } catch {
                //error message
                self.roomIDLabel.text = "Incorrect format"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    // Put your code which should be executed with a delay here
                    self.roomIDLabel.text = "Connected !"
                }
            }
        }
    }
    
    func setColor(r: Int, g: Int, b: Int) {
        if (originPosition == nil) {
            return
        }
        
        red = r
        green = g
        blue = b
    }
    
    func removeCube(x: Float, y: Float, z: Float) {
        if (originPosition == nil) {
            return
        }
        //小数点以下を .0 または .5 に変換
        let _x: Float = round(2.0 * x) / 2.0
        let _y: Float = round(2.0 * y) / 2.0
        let _z: Float = round(2.0 * z) / 2.0
        
        let cubeNode = cubeNodes[String(_x) + "_" + String(_y) + "_" + String(_z)]
        if (cubeNode == nil) {
            return
        }
        
        cubeNode?.removeFromParentNode()
        //message
        self.roomIDLabel.text = "Remove a cube"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Put your code which should be executed with a delay here
            self.roomIDLabel.text = "Connected !"
        }
    }
    
    func reset() {
        if (originPosition == nil) {
            return
        }
        //message
        self.roomIDLabel.text = "Reset"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Put your code which should be executed with a delay here
            self.roomIDLabel.text = "Connected !"
        }
        
        for (id, cubeNode) in cubeNodes {
            cubeNode.removeFromParentNode()
        }
        cubeNodes = [:]
    }
    
    @IBAction func togglePlanesButtonTapped(_ sender: UIButton) {
        if (self.settingOrigin) {
            self.settingOrigin = false
            self.xAxisNode?.isHidden = true
            self.yAxisNode?.isHidden = true
            self.zAxisNode?.isHidden = true
            
            togglePlanesButton.setTitle("Show Planes", for: .normal)
            
            for (identifier, planeNode) in planeNodes {
                planeNode.isHidden = true
            }
        } else {
            self.settingOrigin = true
            self.xAxisNode.isHidden = false
            self.yAxisNode.isHidden = false
            self.zAxisNode.isHidden = false
            
            togglePlanesButton.setTitle("Hide Planes", for: .normal)
            
            for (identifier, planeNode) in planeNodes {
                planeNode.isHidden = false
            }
        }
    }
    
    @IBAction func helpButtonTapped(_ sender: UIButton) {
        guard let url = URL(string: "https://github.com/champierre/s2ar/blob/master/README.md") else { return }
        UIApplication.shared.open(url)
    }
    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        // Set the scene to the view
        sceneView.scene = SCNScene(named: "art.scnassets/main.scn")!
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
        
        sceneView.autoenablesDefaultLighting = false
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapFrom))
        tapGestureRecognizer.numberOfTapsRequired = 1
        sceneView.addGestureRecognizer(tapGestureRecognizer)
        
        // WebSocket
        let socket = manager.defaultSocket
        
        socket.on(clientEvent: .connect) {data, ack in
            self.roomId = String(format: "%04d", Int(arc4random_uniform(10000))) + "-" + String(format: "%04d", Int(arc4random_uniform(10000)))
            self.roomIDLabel.text = "ID: " + self.roomId
            var jsonDic = Dictionary<String, Any>()
            jsonDic["roomId"] = self.roomId
            jsonDic["command"] = "join"
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: jsonDic)
                let jsonStr = String(bytes: jsonData, encoding: .utf8)!
                socket.emit("from_client", jsonStr)
            } catch (let e) {
                print(e)
            }
        }
        
        socket.on("from_server") { data, ack in
            self.roomIDLabel.text = "Connected !"
            if let msg = data[0] as? String {
                print(msg)
                let units = msg.components(separatedBy: ":")
                let action = units[0]
                switch action {
                case "change_cube_size":
                    let magnification = Float(units[1])
                    self.changeCubeSize(magnification: magnification!)
                case "set_cube":
                    let x = Float(units[1])
                    let y = Float(units[2])
                    let z = Float(units[3])
                    self.setCube(x: x!, y: y!, z: z!)
                case "set_box":
                    let x = Int(units[1])
                    let y = Int(units[2])
                    let z = Int(units[3])
                    let w = Int(units[4])
                    let d = Int(units[5])
                    let h = Int(units[6])
                    self.setBox(x: x!, y: y!, z: z!, w: w!, d: d!, h: h!)
                case "set_cylinder":
                    let x = Int(units[1])
                    let y = Int(units[2])
                    let z = Int(units[3])
                    let r = Int(units[4])
                    let h = Int(units[5])
                    let a = units[6]
                    self.setCylinder(x: x!, y: y!, z: z!, r: r!, h: h!, a: a)
                case "set_hexagon":
                    let x = Int(units[1])
                    let y = Int(units[2])
                    let z = Int(units[3])
                    let r = Int(units[4])
                    let h = Int(units[5])
                    let a = units[6]
                    self.setHexagon(x: x!, y: y!, z: z!, r: r!, h: h!, a: a)
                case "set_sphere":
                    let x = Int(units[1])
                    let y = Int(units[2])
                    let z = Int(units[3])
                    let r = Int(units[4])
                    self.setSphere(x: x!, y: y!, z: z!, r: r!)
                case "set_char":
                    let x = Int(units[1])
                    let y = Int(units[2])
                    let z = Int(units[3])
                    let c = units[4]
                    let a = units[5]
                    self.setChar(x: x!, y: y!, z: z!, c: c, a: a)
                case "set_line":
                    let x1 = Int(units[1])
                    let y1 = Int(units[2])
                    let z1 = Int(units[3])
                    let x2 = Int(units[4])
                    let y2 = Int(units[5])
                    let z2 = Int(units[6])
                    self.setLine(x1: x1!, y1: y1!, z1: z1!, x2: x2!, y2: y2!, z2: z2!)
                case "set_roof":
                    let x = Int(units[1])
                    let y = Int(units[2])
                    let z = Int(units[3])
                    let w = Int(units[4])
                    let d = Int(units[5])
                    let h = Int(units[6])
                    let a = units[7]
                    self.setRoof(_x: x!, _y: y!, _z: z!, w: w!, d: d!, h: h!, a: a)
                case "polygon_file_format":
                    let x = Int(units[1])
                    let y = Int(units[2])
                    let z = Int(units[3])
                    let ply_file = units[4]
                    self.polygonFileFormat(x: x!, y: y!, z: z!, ply_file: ply_file)
                case "animation":
                    let x = Int(units[1])
                    let y = Int(units[2])
                    let z = Int(units[3])
                    let differenceX = Int(units[4])
                    let differenceY = Int(units[5])
                    let differenceZ = Int(units[6])
                    let time = Double(units[7])
                    let times = Int(units[8])
                    let files = units[9]
                    self.animation(x: x!, y: y!, z: z!, differenceX: differenceX!, differenceY: differenceY!, differenceZ: differenceZ!, time: time!, times: times!, files: files)
                case "map":
                    let map_data = units[1]
                    let width = Int(units[2])
                    let height = Int(units[3])
                    let magnification = Float(units[4])
                    let r1 = Int(units[5])
                    let g1 = Int(units[6])
                    let b1 = Int(units[7])
                    let r2 = Int(units[8])
                    let g2 = Int(units[9])
                    let b2 = Int(units[10])
                    let upward = Int(units[11])
                    self.map(map_data: map_data, width: width!, height: height!, magnification: magnification!, r1: r1!, g1: g1!, b1: b1!, r2: r2!, g2: g2!, b2: b2!, upward: upward!)
                case "pin":
                    let pin_data = units[1]
                    let width = Int(units[2])
                    let height = Int(units[3])
                    let magnification = Float(units[4])
                    let up_left_latitude = Float(units[5])
                    let up_left_longitude = Float(units[6])
                    let down_right_latitude = Float(units[7])
                    let down_right_longitude = Float(units[8])
                    let step = Int(units[9])
                    self.pin(pin_data: pin_data, width: width!, height: height!, magnification: magnification!, up_left_latitude: up_left_latitude!, up_left_longitude: up_left_longitude!, down_right_latitude: down_right_latitude!, down_right_longitude: down_right_longitude!, step: step!)
                case "molecular_structure":
                    let x = Double(units[1])
                    let y = Double(units[2])
                    let z = Double(units[3])
                    let magnification = Double(units[4])
                    let mld_file = units[5]
                    self.molecular_structure(x: x!, y: y!, z: z!, magnification: magnification!, mld_file: mld_file)
                case "set_color":
                    let r = Int(units[1])
                    let g = Int(units[2])
                    let b = Int(units[3])
                    self.setColor(r: r!, g: g!, b: b!)
                case "remove_cube":
                    let x = Float(units[1])
                    let y = Float(units[2])
                    let z = Float(units[3])
                    self.removeCube(x: x!, y: y!, z: z!)
                case "reset":
                    self.reset()
                default:
                    print("default")
                }
            }
        }
        
        socket.connect()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    // MARK: - ARSCNViewDelegate
    
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    @objc func handleTapFrom(recognizer: UITapGestureRecognizer) {
        if !settingOrigin {
            return
        }
        let pos = recognizer.location(in: sceneView)
        let results = sceneView.hitTest(pos, types: .existingPlaneUsingExtent)
        if results.count == 0 {
            return
        }
        guard let hitResult = results.first else { return }
        
        if originPosition != nil {
            originPosition = SCNVector3Make(hitResult.worldTransform.columns.3.x,
                                            hitResult.worldTransform.columns.3.y,
                                            hitResult.worldTransform.columns.3.z)
            xAxisNode.position = SCNVector3Make(originPosition.x + 0.2, originPosition.y, originPosition.z)
            yAxisNode.position = SCNVector3Make(originPosition.x, originPosition.y + 0.2, originPosition.z)
            zAxisNode.position = SCNVector3Make(originPosition.x, originPosition.y, originPosition.z + 0.2)
            
            lightNode.position = SCNVector3Make(originPosition.x + CUBE_SIZE * 100,
                                                originPosition.y + CUBE_SIZE * 100,
                                                originPosition.z + CUBE_SIZE * 100)
            
            backLightNode.position = SCNVector3Make(originPosition.x - CUBE_SIZE * 100,
                                                    originPosition.y + CUBE_SIZE * 100,
                                                    originPosition.z - CUBE_SIZE * 100)
        } else {
            let xAxisGeometry = SCNCylinder(radius: CGFloat(0.002), height: CGFloat(0.4))//CUBE SIZE を変更できるように定数に変更した
            xAxisGeometry.firstMaterial?.diffuse.contents = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
            xAxisNode = SCNNode(geometry: xAxisGeometry)
            xAxisNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 0, 0, 1)
            
            let yAxisGeometry = SCNCylinder(radius: CGFloat(0.002), height: CGFloat(0.4))
            yAxisGeometry.firstMaterial?.diffuse.contents = UIColor(red: 0, green: 1, blue: 0, alpha: 1)
            yAxisNode = SCNNode(geometry: yAxisGeometry)
            
            let zAxisGeometry = SCNCylinder(radius: CGFloat(0.002), height: CGFloat(0.4))
            zAxisGeometry.firstMaterial?.diffuse.contents = UIColor(red: 0, green: 0, blue: 1, alpha: 1)
            zAxisNode = SCNNode(geometry: zAxisGeometry)
            zAxisNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1, 0, 0)
            
            xAxisNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
            yAxisNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
            zAxisNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
            
            originPosition = SCNVector3Make(hitResult.worldTransform.columns.3.x,
                                            hitResult.worldTransform.columns.3.y,
                                            hitResult.worldTransform.columns.3.z)
            
            xAxisNode.position = SCNVector3Make(originPosition.x + 0.2, originPosition.y, originPosition.z)
            yAxisNode.position = SCNVector3Make(originPosition.x, originPosition.y + 0.2, originPosition.z)
            zAxisNode.position = SCNVector3Make(originPosition.x, originPosition.y, originPosition.z + 0.2)
            
            sceneView.scene.rootNode.addChildNode(xAxisNode)
            sceneView.scene.rootNode.addChildNode(yAxisNode)
            sceneView.scene.rootNode.addChildNode(zAxisNode)
            
            let light = SCNLight()
            light.type = .directional
            light.intensity = 1000
            light.castsShadow = true
            
            lightNode = SCNNode()
            lightNode.light = light
            lightNode.position = SCNVector3Make(originPosition.x + CUBE_SIZE * 100,
                                                originPosition.y + CUBE_SIZE * 100,
                                                originPosition.z + CUBE_SIZE * 100)
            
            let constraint = SCNLookAtConstraint(target: xAxisNode)
            constraint.isGimbalLockEnabled = true
            
            lightNode.constraints = [constraint]
            sceneView.scene.rootNode.addChildNode(lightNode)
            
            let backLight = SCNLight()
            backLight.type = .directional
            backLight.intensity = 100
            light.castsShadow = true
            
            backLightNode = SCNNode()
            backLightNode.light = backLight
            backLightNode.position = SCNVector3Make(originPosition.x - CUBE_SIZE * 100,
                                                    originPosition.y + CUBE_SIZE * 100,
                                                    originPosition.z - CUBE_SIZE * 100)
            
            backLightNode.constraints = [constraint]
            sceneView.scene.rootNode.addChildNode(backLightNode)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else {fatalError()}
        
        let geometry = SCNPlane(width: CGFloat(planeAnchor.extent.x),
                                height: CGFloat(planeAnchor.extent.z))
        
        geometry.materials.first?.diffuse.contents = UIImage(named: "grid.png")
        let material = geometry.materials.first
        material?.diffuse.contentsTransform = SCNMatrix4MakeScale(planeAnchor.extent.x, planeAnchor.extent.z, 1)
        material?.diffuse.wrapS = SCNWrapMode.repeat
        material?.diffuse.wrapT = SCNWrapMode.repeat
        
        let planeNode = SCNNode(geometry: geometry)
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1, 0, 0)
        planeNode.isHidden = !settingOrigin
        
        planeNodes[anchor.identifier] = planeNode
        
        DispatchQueue.main.async(execute: {
            node.addChildNode(planeNode)
        })
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else {fatalError()}
        
        let planeNode = planeNodes[anchor.identifier]
        if planeNode == nil {
            return
        }
        
        let geometry = SCNPlane(width: CGFloat(planeAnchor.extent.x),
                                height: CGFloat(planeAnchor.extent.z))
        
        geometry.materials.first?.diffuse.contents = UIImage(named: "grid.png")
        
        let material = geometry.materials.first
        material?.diffuse.contentsTransform = SCNMatrix4MakeScale(planeAnchor.extent.x, planeAnchor.extent.z, 1)
        material?.diffuse.wrapS = SCNWrapMode.repeat
        material?.diffuse.wrapT = SCNWrapMode.repeat
        
        planeNode?.geometry = geometry
        planeNode?.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1, 0, 0)
        planeNode?.isHidden = !settingOrigin
        
        planeNode?.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z);
        
        planeNodes[anchor.identifier] = planeNode
    }
}
