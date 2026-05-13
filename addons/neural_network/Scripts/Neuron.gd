@icon("res://addons/neural_network/icon.svg")

class_name Neuron
extends RefCounted

var ID :Vector2i = Vector2i.ZERO

enum Status {Active,Passive}
enum Type {SingleNeuron,InputLayer,HiddenLayer,OutputLayer}

var status :=Neuron.Status.Active
var type := Neuron.Type.SingleNeuron

var links :Array[Link] = []

var value :float = 0.0

func SetLink(link :Link = null):
	self.links.append(link)
	pass

func SetLinkWithNeuron(from :Neuron,to :Neuron = self) -> Link:
	var tempLink :Link = Link.new()
	tempLink.from_ID = from.ID
	tempLink.to_ID = to.ID
	links.append(tempLink)
	return tempLink
	
func SetLinkWithWeight(weight :float = 0.0, from :Neuron = null ,to :Neuron = self) -> Link:
	var tempLink :Link = SetLinkWithNeuron(from)
	tempLink.weight = weight
	return tempLink

func GetNeuronData() -> Dictionary:
	var tempLinkArray :Array = []
	for link in links:
		tempLinkArray.append(link.getData())
	var data :Dictionary = {
		ID = self.ID,
		value = self.value,
		status = self.status,
		type = self.type,
		links = tempLinkArray
	}
	return data
